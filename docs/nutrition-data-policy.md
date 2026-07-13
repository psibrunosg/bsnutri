# Política de dados de composição nutricional

Status: proposta para o piloto. Revisão obrigatória antes de importar ou redistribuir qualquer base.

## Objetivo

O BSNutri pode consultar TACO, TBCA e USDA FoodData Central, mas não deve misturar valores sem preservar a origem. Cada alimento e cada nutriente precisam ser rastreáveis até uma fonte, edição e registro específicos. Valores calculados auxiliam o profissional e não substituem sua revisão.

## Fontes previstas

| Fonte | Uso preferencial | Identificador de origem | Licença e condição operacional |
| --- | --- | --- | --- |
| TACO | Alimentos brasileiros analisados na edição adotada | código da tabela, quando existir, mais edição | A 4ª edição revisada e ampliada é NEPA/UNICAMP, 2011. A página do arquivo hospedado em `gov.br` declara CC BY-ND 3.0 para o conteúdo do site, mas isso não prova por si só a licença da base estruturada nem autoriza adaptação. Antes de extrair ou redistribuir dados, registrar uma análise jurídica/documental da edição original. Até lá, permitir referência ou entrada revisada, sem empacotar o dataset no repositório. |
| TBCA | Alimentos e preparações brasileiras com cobertura nutricional mais ampla | identificador estável exibido pela TBCA, versão e URL do registro | Licença de redistribuição não confirmada nesta política. Não fazer scraping, espelhamento ou importação em massa. Obter autorização ou termos explícitos e arquivar a evidência antes da ingestão. Consulta manual não elimina obrigações de atribuição ou uso. |
| USDA FoodData Central | Complemento internacional e alimentos sem equivalente brasileiro | `fdcId` e tipo de dado | Dados publicados em domínio público sob CC0 1.0. A USDA solicita atribuição. A API exige chave, limita por padrão a 1.000 requisições/hora/IP e proíbe expor a chave no repositório ou cliente. A integração deve ocorrer por backend/Edge Function. |

Referências oficiais consultadas em 12/07/2026:

- [TACO, arquivo disponibilizado pelo Ministério da Agricultura](https://www.gov.br/agricultura/pt-br/assuntos/inspecao/produtos-vegetal/legislacao-programas-nacionais-e-seguranca-dos-alimentos-1/legislacao/legislacao-vinhos-e-bebidas/tabela-brasileira-de-composicao-de-alimentos_taco_2011.pdf/view)
- [TBCA](https://www.tbca.net.br/)
- [USDA FoodData Central API Guide](https://fdc.nal.usda.gov/api-guide/)

## Campos essenciais

### Registro do alimento

- `id` interno imutável;
- `name`, descrição original e nome normalizado para busca;
- `source`: `taco`, `tbca`, `usda_fdc`, `clinic` ou `community`;
- `source_food_id`, `source_url`, `source_version` e `source_retrieved_at`;
- categoria, estado/preparo (cru, cozido, drenado etc.) e parte comestível;
- base de referência, normalmente `per_100_g`, e unidade da porção-base;
- densidade ou fator de conversão somente quando documentado;
- idioma, país e observações metodológicas;
- estado de revisão: `draft`, `reviewed`, `approved`, `deprecated`;
- responsável e datas de criação, revisão e aprovação;
- `license_id`, texto de atribuição e evidência dos termos aplicáveis.

### Valor de nutriente

- identificador canônico do nutriente e nome fornecido pela fonte;
- valor, unidade e base (`100 g`, `100 ml`, porção etc.);
- tipo do valor: analisado, calculado, estimado, traço, abaixo do limite ou ausente;
- método, número de amostras, incerteza e limite de detecção, quando fornecidos;
- identificador do nutriente na fonte;
- origem e versão próprias quando o valor vier de fonte diferente da ficha do alimento.

`0`, traço e ausente não são equivalentes. Ausência deve ser `null` com um código de estado, nunca convertida silenciosamente em zero. A unidade original deve ser guardada; conversões devem registrar fórmula, fator e versão.

## Prioridade e conflitos

O profissional escolhe a tabela prioritária. O sistema não resolve divergências automaticamente. Quando houver mais de um registro candidato, deve mostrar lado a lado: fonte, edição, estado/preparo, base, nutrientes relevantes e data de consulta. A escolha fica registrada no plano.

Não se deve completar micronutrientes ausentes juntando fontes diferentes sem criar um registro derivado explícito. Um registro derivado precisa listar cada contribuição, regra de combinação, responsável e revisão profissional.

## Versionamento e reprodutibilidade

1. Cada importação recebe um `dataset_release_id` imutável, com fonte, edição/release, data, licença, URL, hash do artefato e script/importador usado.
2. Correções criam nova versão; valores já publicados não são sobrescritos.
3. Ao publicar um plano, salvar um snapshot dos alimentos, nutrientes, unidades, fatores, equações e arredondamentos utilizados.
4. Atualizações de tabela podem sugerir recálculo, mas nunca alteram retroativamente um plano publicado.
5. Toda alteração manual registra autor, motivo, valor anterior e novo valor.
6. Registros removidos pela fonte tornam-se `deprecated`; permanecem disponíveis para auditoria de planos históricos.

## Cadastro próprio e comunitário

Alimentos da clínica exigem cadastro completo conforme os campos essenciais, evidência primária (laudo, ficha técnica ou rótulo válido), revisão e identificação clara de que não pertencem às tabelas oficiais. Conteúdo comunitário permanece privado até moderação. A aprovação pública não muda sua origem nem o transforma em dado oficial.

Fotos de rótulos e resultados de IA são apenas auxílio de transcrição. Devem guardar a imagem/evidência com acesso protegido, indicar campos inferidos e exigir conferência humana antes do uso em plano.

## Gate para implementação

Antes de importar uma fonte, é obrigatório:

1. confirmar termos, licença e forma de atribuição na fonte original;
2. documentar autorização para armazenamento, transformação e redistribuição comercial;
3. mapear identificadores e unidades sem perda semântica;
4. validar uma amostra com o nutricionista parceiro;
5. testar duplicidades, ausentes, traços, conversões e arredondamentos;
6. registrar release e hash e executar importação reproduzível;
7. impedir que chaves de API ou datasets não autorizados cheguem ao GitHub Pages.

Enquanto TACO e TBCA não concluírem esse gate, o piloto deve usar fixtures sintéticas e cadastros próprios revisados. Para USDA, a licença permite uso, mas a chave e as cotas ainda exigem integração segura pelo backend.
