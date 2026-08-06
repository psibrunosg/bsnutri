-- Seed de alimentos dos 8 modelos de prática dietética (docs/seed/*.csv), 450 linhas de origem,
-- deduplicadas por (nome, preparo) com union dos diet_tags quando o mesmo alimento aparece em
-- mais de um modelo (ex.: azeite de oliva está em Mediterrânea, MIND, Cetogênica...).
-- Fonte: TBCA/USP e USDA SR Legacy, porção 100g. Revisão obrigatória por nutricionista antes de uso clínico.

do $$
begin
  if (
    select count(*)
    from public.nutrients
    where code in ('energy_kcal', 'protein_g', 'carbohydrate_g', 'fat_g')
  ) <> 4 then
    raise exception 'Definições nutricionais obrigatórias não estão disponíveis';
  end if;
end
$$;

with source as (
  insert into public.food_sources (
    code,
    name,
    license_name,
    attribution_text,
    dataset_version,
    released_on
  )
  values (
    'bsnutri_praticas_dieteticas_20260724',
    'Alimentos dos modelos de prática dietética (Mediterrânea, DASH, MIND, Cetogênica, Low Carb, Vegana, Paleo, Guia Alimentar BR)',
    'Domínio público (TBCA/USP, USDA SR Legacy)',
    'Valores aproximados de literatura (TBCA/USP, USDA SR Legacy); porção de referência 100g. Seed de docs/seed/*.csv do BSNutri.',
    'diet_catalog_2026-07-24_v1',
    date '2026-07-24'
  )
  on conflict (code) do update set
    name = excluded.name,
    license_name = excluded.license_name,
    attribution_text = excluded.attribution_text,
    dataset_version = excluded.dataset_version,
    released_on = excluded.released_on,
    imported_at = now()
  returning id, dataset_version
),
raw as (
  select 'mediterranean' as diet, line from regexp_split_to_table($med$
nome;preparo;energia;proteína;carboidrato;gordura
Azeite de oliva extravirgem;líquido;884;0;0;100.0
Salmão;grelhado;208;20.0;0;13.0
Sardinha;grelhada;208;24.0;0;11.0
Atum fresco;grelhado;127;24.0;0;3.0
Cavala;grelhada;180;22.0;0;9.5
Bacalhau;cozido;105;23.0;0;0.9
Camarão;cozido;99;24.0;0.2;0.3
Polvo;cozido;82;17.0;2.0;1.0
Lula;cozida;92;16.0;3.0;1.5
Grão-de-bico;cozido;121;7.0;21.0;2.0
Lentilha;cozida;93;6.3;16.3;0.5
Feijão branco;cozido;83;5.5;14.0;0.5
Feijão carioca;cozido;76;4.8;13.6;0.3
Ervilha;cozida;81;5.0;14.0;0.4
Soja;cozida;141;14.0;8.0;7.0
Tofu;fresco;76;8.0;1.9;4.8
Arroz integral;cozido;124;2.6;25.6;1.0
Quinoa;cozida;120;4.4;21.3;1.9
Aveia em flocos;bruta;394;13.2;67.7;8.4
Pão integral;assado;253;9.0;49.0;3.0
Macarrão integral;cozido;124;5.0;26.0;0.8
Castanha do Brasil;in natura;656;14.0;12.0;66.0
Castanha de caju;in natura;553;18.0;30.0;44.0
Amêndoa;in natura;579;21.0;22.0;50.0
Noz;in natura;654;15.0;14.0;65.0
Linhaça;em grão;534;18.0;29.0;42.0
Chia;em grão;486;17.0;42.0;31.0
Abacate;in natura;160;2.0;9.0;15.0
Azeitona preta;conserva;155;1.5;4.5;16.0
Tomate;in natura;21;1.1;4.7;0.2
Tomate cereja;in natura;22;1.0;4.5;0.2
Berinjela;cozida;35;0.8;8.7;0.2
Abobrinha;cozida;15;1.1;3.0;0.2
Brócolis;cozido;35;2.4;7.0;0.4
Couve;cozida;27;1.7;5.0;0.5
Espinafre;cozido;23;2.9;3.6;0.3
Rúcula;in natura;25;2.6;3.7;0.7
Alface;in natura;15;1.4;2.8;0.2
Cenoura;in natura;41;0.9;10.0;0.2
Pimentão vermelho;in natura;26;1.0;6.0;0.3
Cebola;in natura;40;1.1;9.3;0.1
Alho;in natura;149;6.4;33.0;0.5
Maçã;in natura;52;0.3;14.0;0.2
Laranja pera;in natura;47;0.9;12.0;0.1
Uva;in natura;69;0.7;18.0;0.2
Morango;in natura;32;0.7;7.7;0.3
Figo;in natura;74;0.8;19.0;0.3
Pera;in natura;57;0.4;15.0;0.1
Peito de frango;grelhado;165;31.0;0;3.6
Ovo de galinha;cozido;155;13.0;1.1;11.0
Queijo feta;fresco;264;14.0;4.1;21.0
Iogurte natural;líquido;51;4.1;4.7;1.5
Vinho tinto;líquido;85;0.1;2.6;0
$med$, E'\r?\n') as line
  union all
  select 'dash', line from regexp_split_to_table($dash$
nome;preparo;energia;proteína;carboidrato;gordura
Banana nanica;in natura;89;1.1;23.0;0.3
Maçã;in natura;52;0.3;14.0;0.2
Laranja pera;in natura;47;0.9;12.0;0.1
Tangerina;in natura;53;0.8;13.0;0.3
Mamão papaia;in natura;43;0.5;11.0;0.3
Abacaxi;in natura;50;0.5;13.0;0.1
Manga;in natura;60;0.8;15.0;0.4
Uva;in natura;69;0.7;18.0;0.2
Morango;in natura;32;0.7;7.7;0.3
Melancia;in natura;30;0.6;7.6;0.2
Melão;in natura;34;0.8;8.2;0.2
Arroz integral;cozido;124;2.6;25.6;1.0
Aveia em flocos;bruta;394;13.2;67.7;8.4
Quinoa;cozida;120;4.4;21.3;1.9
Pão integral;assado;253;9.0;49.0;3.0
Macarrão integral;cozido;124;5.0;26.0;0.8
Cuscuz nordestino;cozido;112;3.8;23.0;0.2
Tomate;in natura;21;1.1;4.7;0.2
Cenoura;cozida;35;0.8;8.0;0.2
Beterraba;cozida;44;1.7;10.0;0.2
Brócolis;cozido;35;2.4;7.0;0.4
Couve-flor;cozida;20;1.4;4.0;0.2
Couve;cozida;27;1.7;5.0;0.5
Espinafre;cozido;23;2.9;3.6;0.3
Alface;in natura;15;1.4;2.8;0.2
Rúcula;in natura;25;2.6;3.7;0.7
Abobrinha;cozida;15;1.1;3.0;0.2
Chuchu;cozido;19;0.4;4.5;0.1
Pimentão vermelho;in natura;26;1.0;6.0;0.3
Batata-doce;cozida;86;1.6;20.0;0.1
Leite desnatado;líquido;35;3.4;5.0;0.2
Iogurte natural;líquido;51;4.1;4.7;1.5
Iogurte grego;líquido;97;6.0;4.0;6.0
Queijo cottage;fresco;98;11.0;3.4;4.3
Queijo minas frescal;fresco;240;17.0;3.2;17.0
Peito de frango;grelhado;165;31.0;0;3.6
Tilápia;grelhada;128;26.0;0;2.7
Salmão;grelhado;208;20.0;0;13.0
Atum em conserva;em água;108;24.0;0;0.8
Patinho;cozido;163;26.0;0;6.0
Filé mignon;grelhado;156;26.0;0;5.0
Feijão carioca;cozido;76;4.8;13.6;0.3
Lentilha;cozida;93;6.3;16.3;0.5
Grão-de-bico;cozido;121;7.0;21.0;2.0
Amêndoa;in natura;579;21.0;22.0;50.0
Castanha de caju;in natura;553;18.0;30.0;44.0
Azeite de oliva;líquido;884;0;0;100.0
Óleo de canola;líquido;884;0;0;100.0
Cenoura;in natura;41;0.9;10.0;0.2
Espinafre;in natura;23;2.9;3.6;0.4
Batata;cozida;86;1.7;19.0;0.1
$dash$, E'\r?\n') as line
  union all
  select 'mind', line from regexp_split_to_table($mind$
nome;preparo;energia;proteína;carboidrato;gordura
Couve;cozida;27;1.7;5.0;0.5
Espinafre;cozido;23;2.9;3.6;0.3
Espinafre;in natura;23;2.9;3.6;0.4
Rúcula;in natura;25;2.6;3.7;0.7
Agrião;in natura;11;1.5;1.8;0.1
Alface;in natura;15;1.4;2.8;0.2
Brócolis;cozido;35;2.4;7.0;0.4
Brócolis;in natura;34;2.8;7.0;0.4
Couve-flor;cozida;20;1.4;4.0;0.2
Couve-de-bruxelas;cozida;36;2.6;7.0;0.5
Morango;in natura;32;0.7;7.7;0.3
Amora;in natura;43;1.4;10.0;0.5
Framboesa;in natura;52;1.2;12.0;0.7
Mirtilo;in natura;57;0.7;14.0;0.3
Cereja;in natura;50;1.0;12.0;0.3
Castanha do Brasil;in natura;656;14.0;12.0;66.0
Castanha de caju;in natura;553;18.0;30.0;44.0
Amêndoa;in natura;579;21.0;22.0;50.0
Noz;in natura;654;15.0;14.0;65.0
Linhaça;em grão;534;18.0;29.0;42.0
Chia;em grão;486;17.0;42.0;31.0
Arroz integral;cozido;124;2.6;25.6;1.0
Quinoa;cozida;120;4.4;21.3;1.9
Aveia em flocos;bruta;394;13.2;67.7;8.4
Pão integral;assado;253;9.0;49.0;3.0
Macarrão integral;cozido;124;5.0;26.0;0.8
Feijão carioca;cozido;76;4.8;13.6;0.3
Lentilha;cozida;93;6.3;16.3;0.5
Grão-de-bico;cozido;121;7.0;21.0;2.0
Ervilha;cozida;81;5.0;14.0;0.4
Soja;cozida;141;14.0;8.0;7.0
Peito de frango;grelhado;165;31.0;0;3.6
Coxa de frango;cozida;209;26.0;0;11.0
Tilápia;grelhada;128;26.0;0;2.7
Salmão;grelhado;208;20.0;0;13.0
Sardinha;grelhada;208;24.0;0;11.0
Atum fresco;grelhado;127;24.0;0;3.0
Azeite de oliva extravirgem;líquido;884;0;0;100.0
Tomate;in natura;21;1.1;4.7;0.2
Cenoura;in natura;41;0.9;10.0;0.2
Cebola;in natura;40;1.1;9.3;0.1
Alho;in natura;149;6.4;33.0;0.5
Vinho tinto;líquido;85;0.1;2.6;0
$mind$, E'\r?\n') as line
  union all
  select 'ketogenic', line from regexp_split_to_table($keto$
nome;preparo;energia;proteína;carboidrato;gordura
Abacate;in natura;160;2.0;9.0;15.0
Azeite de oliva;líquido;884;0;0;100.0
Óleo de coco;líquido;862;0;0;100.0
Manteiga;temperatura ambiente;717;0.9;0.1;81.0
Banha de porco;líquida;902;0;0;100.0
Peito de frango;grelhado;165;31.0;0;3.6
Coxa de frango;assada;215;25.0;0;12.0
Patinho;cozido;163;26.0;0;6.0
Alcatra;grelhada;163;24.0;0;6.6
Picanha;grelhada;210;23.0;0;13.0
Bacon;frito;540;12.0;1.0;55.0
Linguiça toscana;grelhada;280;18.0;3.0;22.0
Lombo suíno;assado;198;28.0;0;8.0
Tilápia;grelhada;128;26.0;0;2.7
Salmão;grelhado;208;20.0;0;13.0
Sardinha;grelhada;208;24.0;0;11.0
Atum fresco;grelhado;127;24.0;0;3.0
Ovo de galinha;cozido;155;13.0;1.1;11.0
Omelete simples;preparada;175;13.0;1.5;13.0
Queijo mussarela;fresco;280;22.0;3.0;20.0
Queijo prato;fresco;360;23.0;3.0;28.0
Requeijão;cremoso;257;9.0;3.0;23.0
Queijo coalho;grelhado;300;22.0;2.0;23.0
Queijo parmesão;ralado;453;38.0;4.0;32.0
Tofu;fresco;76;8.0;1.9;4.8
Castanha do Brasil;in natura;656;14.0;12.0;66.0
Castanha de caju;in natura;553;18.0;30.0;44.0
Amêndoa;in natura;579;21.0;22.0;50.0
Noz;in natura;654;15.0;14.0;65.0
Macadâmia;in natura;718;8.0;14.0;76.0
Linhaça;em grão;534;18.0;29.0;42.0
Chia;em grão;486;17.0;42.0;31.0
Couve;cozida;27;1.7;5.0;0.5
Espinafre;cozido;23;2.9;3.6;0.3
Brócolis;cozido;35;2.4;7.0;0.4
Couve-flor;cozida;20;1.4;4.0;0.2
Abobrinha;cozida;15;1.1;3.0;0.2
Chuchu;cozido;19;0.4;4.5;0.1
Berinjela;cozida;35;0.8;8.7;0.2
Pepino;in natura;15;0.6;3.6;0.1
Rúcula;in natura;25;2.6;3.7;0.7
Acelga;cozida;20;1.8;4.0;0.1
Quiabo;cozido;33;1.9;7.0;0.2
Creme de leite;líquido;220;2.5;3.5;22.0
Leite integral;líquido;61;3.2;4.8;3.3
$keto$, E'\r?\n') as line
  union all
  select 'low_carb', line from regexp_split_to_table($lowcarb$
nome;preparo;energia;proteína;carboidrato;gordura
Peito de frango;grelhado;165;31.0;0;3.6
Coxa de frango;cozida;209;26.0;0;11.0
Patinho;cozido;163;26.0;0;6.0
Alcatra;grelhada;163;24.0;0;6.6
Picanha;grelhada;210;23.0;0;13.0
Filé mignon;grelhado;156;26.0;0;5.0
Contrafilé;grelhado;170;25.0;0;7.0
Lombo suíno;assado;198;28.0;0;8.0
Bisteca suína;grelhada;235;22.0;0;16.0
Tilápia;grelhada;128;26.0;0;2.7
Salmão;grelhado;208;20.0;0;13.0
Sardinha;grelhada;208;24.0;0;11.0
Atum fresco;grelhado;127;24.0;0;3.0
Camarão;cozido;99;24.0;0.2;0.3
Ovo de galinha;cozido;155;13.0;1.1;11.0
Omelete simples;preparada;175;13.0;1.5;13.0
Queijo minas frescal;fresco;240;17.0;3.2;17.0
Queijo cottage;fresco;98;11.0;3.4;4.3
Tofu;fresco;76;8.0;1.9;4.8
Azeite de oliva;líquido;884;0;0;100.0
Óleo de canola;líquido;884;0;0;100.0
Abacate;in natura;160;2.0;9.0;15.0
Castanha do Brasil;in natura;656;14.0;12.0;66.0
Castanha de caju;in natura;553;18.0;30.0;44.0
Amêndoa;in natura;579;21.0;22.0;50.0
Linhaça;em grão;534;18.0;29.0;42.0
Chia;em grão;486;17.0;42.0;31.0
Couve;cozida;27;1.7;5.0;0.5
Espinafre;cozido;23;2.9;3.6;0.3
Brócolis;cozido;35;2.4;7.0;0.4
Couve-flor;cozida;20;1.4;4.0;0.2
Abobrinha;cozida;15;1.1;3.0;0.2
Chuchu;cozido;19;0.4;4.5;0.1
Berinjela;cozida;35;0.8;8.7;0.2
Pepino;in natura;15;0.6;3.6;0.1
Quiabo;cozido;33;1.9;7.0;0.2
Tomate;in natura;21;1.1;4.7;0.2
Cebola;in natura;40;1.1;9.3;0.1
Alho;in natura;149;6.4;33.0;0.5
Rúcula;in natura;25;2.6;3.7;0.7
Batata-doce;cozida;86;1.6;20.0;0.1
Mandioca;cozida;125;0.6;30.0;0.3
Feijão carioca;cozido;76;4.8;13.6;0.3
Lentilha;cozida;93;6.3;16.3;0.5
Morango;in natura;32;0.7;7.7;0.3
Melancia;in natura;30;0.6;7.6;0.2
Melão;in natura;34;0.8;8.2;0.2
Coco verde;in natura;45;0.7;8.5;1.0
Leite integral;líquido;61;3.2;4.8;3.3
Iogurte natural;líquido;51;4.1;4.7;1.5
$lowcarb$, E'\r?\n') as line
  union all
  select 'vegan', line from regexp_split_to_table($vegan$
nome;preparo;energia;proteína;carboidrato;gordura
Feijão carioca;cozido;76;4.8;13.6;0.3
Feijão preto;cozido;77;4.5;14.0;0.5
Feijão branco;cozido;83;5.5;14.0;0.5
Feijão de corda;cozido;80;5.5;14.0;0.4
Lentilha;cozida;93;6.3;16.3;0.5
Grão-de-bico;cozido;121;7.0;21.0;2.0
Ervilha;cozida;81;5.0;14.0;0.4
Soja;cozida;141;14.0;8.0;7.0
Tofu;fresco;76;8.0;1.9;4.8
Edamame;cozido;121;12.0;9.0;5.0
Proteína texturizada de soja;hidratada;102;12.5;4.5;2.5
Arroz integral;cozido;124;2.6;25.6;1.0
Arroz branco;cozido;130;2.7;28.1;0.3
Quinoa;cozida;120;4.4;21.3;1.9
Aveia em flocos;bruta;394;13.2;67.7;8.4
Pão integral;assado;253;9.0;49.0;3.0
Pão de forma integral;assado;280;9.0;49.0;4.0
Macarrão integral;cozido;124;5.0;26.0;0.8
Azeite de oliva;líquido;884;0;0;100.0
Óleo de soja;líquido;884;0;0;100.0
Óleo de canola;líquido;884;0;0;100.0
Abacate;in natura;160;2.0;9.0;15.0
Coco verde;in natura;45;0.7;8.5;1.0
Coco seco polpa;ralada;354;3.3;15.0;33.0
Castanha do Brasil;in natura;656;14.0;12.0;66.0
Castanha de caju;in natura;553;18.0;30.0;44.0
Amêndoa;in natura;579;21.0;22.0;50.0
Amendoim;torrado;567;26.0;16.0;49.0
Manteiga de amendoim;cremosa;588;25.0;20.0;50.0
Linhaça;em grão;534;18.0;29.0;42.0
Chia;em grão;486;17.0;42.0;31.0
Gergelim;em grão;573;18.0;23.0;50.0
Semente de abóbora;torrada;559;30.0;11.0;49.0
Semente de girassol;torrada;584;21.0;20.0;51.0
Tomate;in natura;21;1.1;4.7;0.2
Cenoura;in natura;41;0.9;10.0;0.2
Cenoura;cozida;35;0.8;8.0;0.2
Couve;cozida;27;1.7;5.0;0.5
Espinafre;cozido;23;2.9;3.6;0.3
Brócolis;cozido;35;2.4;7.0;0.4
Couve-flor;cozida;20;1.4;4.0;0.2
Abobrinha;cozida;15;1.1;3.0;0.2
Rúcula;in natura;25;2.6;3.7;0.7
Beterraba;cozida;44;1.7;10.0;0.2
Pimentão vermelho;in natura;26;1.0;6.0;0.3
Cebola;in natura;40;1.1;9.3;0.1
Alho;in natura;149;6.4;33.0;0.5
Batata-doce;cozida;86;1.6;20.0;0.1
Mandioca;cozida;125;0.6;30.0;0.3
Banana nanica;in natura;89;1.1;23.0;0.3
Maçã;in natura;52;0.3;14.0;0.2
Laranja pera;in natura;47;0.9;12.0;0.1
Mamão papaia;in natura;43;0.5;11.0;0.3
Abacaxi;in natura;50;0.5;13.0;0.1
Manga;in natura;60;0.8;15.0;0.4
Morango;in natura;32;0.7;7.7;0.3
Goiaba;in natura;68;2.6;14.0;1.0
Maracujá;in natura;97;2.2;21.0;0.7
Leite de soja;líquido;40;3.3;2.0;1.5
Leite de amêndoas;líquido;30;1.0;1.0;2.5
Leite de aveia;líquido;48;0.7;9.0;1.0
Pasta de amendoim integral;cremosa;588;25.0;20.0;50.0
Cacau em pó;bruto;228;19.6;54.3;13.7
$vegan$, E'\r?\n') as line
  union all
  select 'paleo', line from regexp_split_to_table($paleo$
nome;preparo;energia;proteína;carboidrato;gordura
Peito de frango;grelhado;165;31.0;0;3.6
Coxa de frango;assada;215;25.0;0;12.0
Patinho;cozido;163;26.0;0;6.0
Alcatra;grelhada;163;24.0;0;6.6
Picanha;grelhada;210;23.0;0;13.0
Filé mignon;grelhado;156;26.0;0;5.0
Contrafilé;grelhado;170;25.0;0;7.0
Músculo;cozido;150;26.0;0;4.0
Acém;cozido;215;26.0;0;12.0
Lombo suíno;assado;198;28.0;0;8.0
Pernil suíno;assado;220;25.0;0;12.0
Tilápia;grelhada;128;26.0;0;2.7
Salmão;grelhado;208;20.0;0;13.0
Sardinha;grelhada;208;24.0;0;11.0
Atum fresco;grelhado;127;24.0;0;3.0
Cavala;grelhada;180;22.0;0;9.5
Camarão;cozido;99;24.0;0.2;0.3
Polvo;cozido;82;17.0;2.0;1.0
Lula;cozida;92;16.0;3.0;1.5
Ovo de galinha;cozido;155;13.0;1.1;11.0
Omelete simples;preparada;175;13.0;1.5;13.0
Abacate;in natura;160;2.0;9.0;15.0
Coco verde;in natura;45;0.7;8.5;1.0
Azeite de oliva;líquido;884;0;0;100.0
Óleo de coco;líquido;862;0;0;100.0
Castanha do Brasil;in natura;656;14.0;12.0;66.0
Castanha de caju;in natura;553;18.0;30.0;44.0
Amêndoa;in natura;579;21.0;22.0;50.0
Noz;in natura;654;15.0;14.0;65.0
Macadâmia;in natura;718;8.0;14.0;76.0
Pistache;in natura;562;20.0;28.0;45.0
Linhaça;em grão;534;18.0;29.0;42.0
Chia;em grão;486;17.0;42.0;31.0
Gergelim;em grão;573;18.0;23.0;50.0
Semente de abóbora;torrada;559;30.0;11.0;49.0
Semente de girassol;torrada;584;21.0;20.0;51.0
Tomate;in natura;21;1.1;4.7;0.2
Cenoura;in natura;41;0.9;10.0;0.2
Cenoura;cozida;35;0.8;8.0;0.2
Couve;cozida;27;1.7;5.0;0.5
Espinafre;cozido;23;2.9;3.6;0.3
Espinafre;in natura;23;2.9;3.6;0.4
Brócolis;cozido;35;2.4;7.0;0.4
Couve-flor;cozida;20;1.4;4.0;0.2
Abobrinha;cozida;15;1.1;3.0;0.2
Berinjela;cozida;35;0.8;8.7;0.2
Pepino;in natura;15;0.6;3.6;0.1
Rúcula;in natura;25;2.6;3.7;0.7
Agrião;in natura;11;1.5;1.8;0.1
Pimentão vermelho;in natura;26;1.0;6.0;0.3
Cebola;in natura;40;1.1;9.3;0.1
Alho;in natura;149;6.4;33.0;0.5
Batata-doce;cozida;86;1.6;20.0;0.1
Banana nanica;in natura;89;1.1;23.0;0.3
Maçã;in natura;52;0.3;14.0;0.2
Laranja pera;in natura;47;0.9;12.0;0.1
Mamão papaia;in natura;43;0.5;11.0;0.3
Abacaxi;in natura;50;0.5;13.0;0.1
Manga;in natura;60;0.8;15.0;0.4
Morango;in natura;32;0.7;7.7;0.3
Goiaba;in natura;68;2.6;14.0;1.0
Maracujá;in natura;97;2.2;21.0;0.7
Caju;in natura;43;1.0;10.0;0.4
$paleo$, E'\r?\n') as line
  union all
  select 'guia_br', line from regexp_split_to_table($guiabr$
nome;preparo;energia;proteína;carboidrato;gordura
Arroz branco;cozido;130;2.7;28.1;0.3
Arroz integral;cozido;124;2.6;25.6;1.0
Feijão carioca;cozido;76;4.8;13.6;0.3
Feijão preto;cozido;77;4.5;14.0;0.5
Feijão verde;cozido;72;5.0;13.5;0.3
Feijão de corda;cozido;80;5.5;14.0;0.4
Lentilha;cozida;93;6.3;16.3;0.5
Grão-de-bico;cozido;121;7.0;21.0;2.0
Ervilha;cozida;81;5.0;14.0;0.4
Milho verde;cozido;98;3.4;21.0;0.6
Mandioca;cozida;125;0.6;30.0;0.3
Farinha de mandioca;bruta;360;1.2;87.0;0.3
Tapioca;preparada;240;0.5;60.0;0.1
Batata;cozida;86;1.7;19.0;0.1
Batata-doce;cozida;86;1.6;20.0;0.1
Inhame;cozido;101;1.5;23.0;0.2
Cará;cozido;87;1.7;19.5;0.2
Batata-baroa;cozida;80;1.5;18.0;0.1
Cuscuz nordestino;cozido;112;3.8;23.0;0.2
Pão francês;assado;270;8.0;56.0;1.0
Pão integral;assado;253;9.0;49.0;3.0
Peito de frango;grelhado;165;31.0;0;3.6
Coxa de frango;cozida;209;26.0;0;11.0
Patinho;cozido;163;26.0;0;6.0
Alcatra;grelhada;163;24.0;0;6.6
Filé mignon;grelhado;156;26.0;0;5.0
Tilápia;grelhada;128;26.0;0;2.7
Sardinha;grelhada;208;24.0;0;11.0
Atum em conserva;em água;108;24.0;0;0.8
Camarão;cozido;99;24.0;0.2;0.3
Ovo de galinha;cozido;155;13.0;1.1;11.0
Leite integral;líquido;61;3.2;4.8;3.3
Leite desnatado;líquido;35;3.4;5.0;0.2
Iogurte natural;líquido;51;4.1;4.7;1.5
Queijo minas frescal;fresco;240;17.0;3.2;17.0
Queijo mussarela;fresco;280;22.0;3.0;20.0
Queijo prato;fresco;360;23.0;3.0;28.0
Azeite de oliva;líquido;884;0;0;100.0
Óleo de soja;líquido;884;0;0;100.0
Manteiga;temperatura ambiente;717;0.9;0.1;81.0
Banana nanica;in natura;89;1.1;23.0;0.3
Banana prata;in natura;92;1.3;23.5;0.3
Maçã;in natura;52;0.3;14.0;0.2
Laranja pera;in natura;47;0.9;12.0;0.1
Tangerina;in natura;53;0.8;13.0;0.3
Mamão papaia;in natura;43;0.5;11.0;0.3
Abacaxi;in natura;50;0.5;13.0;0.1
Manga;in natura;60;0.8;15.0;0.4
Uva;in natura;69;0.7;18.0;0.2
Morango;in natura;32;0.7;7.7;0.3
Melancia;in natura;30;0.6;7.6;0.2
Melão;in natura;34;0.8;8.2;0.2
Pera;in natura;57;0.4;15.0;0.1
Goiaba;in natura;68;2.6;14.0;1.0
Maracujá;in natura;97;2.2;21.0;0.7
Caju;in natura;43;1.0;10.0;0.4
Açaí polpa;congelado;58;0.8;6.2;3.7
Tomate;in natura;21;1.1;4.7;0.2
Cenoura;in natura;41;0.9;10.0;0.2
Cenoura;cozida;35;0.8;8.0;0.2
Beterraba;cozida;44;1.7;10.0;0.2
Abobrinha;cozida;15;1.1;3.0;0.2
Chuchu;cozido;19;0.4;4.5;0.1
Brócolis;cozido;35;2.4;7.0;0.4
Couve;cozida;27;1.7;5.0;0.5
Espinafre;cozido;23;2.9;3.6;0.3
Alface;in natura;15;1.4;2.8;0.2
Rúcula;in natura;25;2.6;3.7;0.7
Agrião;in natura;11;1.5;1.8;0.1
Repolho;in natura;25;1.3;5.8;0.1
Pepino;in natura;15;0.6;3.6;0.1
Pimentão verde;in natura;23;1.0;5.4;0.2
Berinjela;cozida;35;0.8;8.7;0.2
Quiabo;cozido;33;1.9;7.0;0.2
Jiló;cozido;27;1.4;6.0;0.2
Abóbora;cozida;26;1.0;6.5;0.1
Vagem;cozida;35;1.9;7.9;0.2
Palmito;conserva;30;2.5;5.0;0.1
Cebola;in natura;40;1.1;9.3;0.1
Alho;in natura;149;6.4;33.0;0.5
Acelga;cozida;20;1.8;4.0;0.1
Almeirão;in natura;19;1.5;4.0;0.2
$guiabr$, E'\r?\n') as line
),
fields as (
  select diet, string_to_array(line, ';') as fields
  from raw
  where btrim(line) <> '' and lower(btrim(line)) not like 'nome;%'
),
parsed as (
  select
    diet,
    btrim(fields[1]) as name,
    btrim(fields[2]) as preparation_state,
    replace(fields[3], ',', '.')::numeric as energy_kcal,
    replace(fields[4], ',', '.')::numeric as protein_g,
    replace(fields[5], ',', '.')::numeric as carbohydrate_g,
    replace(fields[6], ',', '.')::numeric as fat_g
  from fields
  where cardinality(fields) = 6
),
grouped as (
  select
    lower(name) || '|' || lower(preparation_state) as dedupe_key,
    min(name) as name,
    min(preparation_state) as preparation_state,
    min(energy_kcal) as energy_kcal,
    min(protein_g) as protein_g,
    min(carbohydrate_g) as carbohydrate_g,
    min(fat_g) as fat_g,
    array_agg(distinct diet order by diet) as diet_tags
  from parsed
  group by 1
),
enriched as (
  select 'diet-' || md5(dedupe_key) as source_food_code, grouped.*
  from grouped
),
upserted_foods as (
  insert into public.foods (
    source_id,
    source_food_code,
    name,
    preparation_state,
    catalog_kind,
    source_reference,
    source_accessed_on,
    source_reliability,
    review_status,
    diet_tags
  )
  select
    source.id,
    enriched.source_food_code,
    enriched.name,
    enriched.preparation_state,
    'food',
    'Seed de modelos de prática dietética (Mediterrânea/DASH/MIND/Cetogênica/Low Carb/Vegana/Paleo/Guia BR); valores por 100g',
    date '2026-07-24',
    1,
    'pending_review',
    enriched.diet_tags
  from enriched
  cross join source
  on conflict (source_id, source_food_code) where organization_id is null
  do update set
    name = excluded.name,
    preparation_state = excluded.preparation_state,
    is_active = true,
    diet_tags = array(select distinct unnest(foods.diet_tags || excluded.diet_tags) order by 1),
    source_reference = excluded.source_reference,
    source_accessed_on = excluded.source_accessed_on,
    source_reliability = excluded.source_reliability,
    review_status = 'pending_review',
    reviewed_at = null,
    reviewed_by = null,
    updated_at = now()
  returning id, source_food_code
)
insert into public.food_nutrient_values (
  food_id,
  nutrient_id,
  amount_per_100g,
  data_version
)
select
  food.id,
  nutrient.id,
  value.amount,
  source.dataset_version
from upserted_foods food
join enriched on enriched.source_food_code = food.source_food_code
cross join source
cross join lateral (
  values
    ('energy_kcal'::text, enriched.energy_kcal),
    ('protein_g'::text, enriched.protein_g),
    ('carbohydrate_g'::text, enriched.carbohydrate_g),
    ('fat_g'::text, enriched.fat_g)
) as value(code, amount)
join public.nutrients nutrient on nutrient.code = value.code
on conflict (food_id, nutrient_id) do update set
  amount_per_100g = excluded.amount_per_100g,
  data_version = excluded.data_version;
