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
    'bsnutri_user_catalog_20260724',
    'Lista inicial fornecida pela clínica',
    'Origem não licenciada; uso interno pendente de curadoria',
    'Dados fornecidos pelo usuário em 24/07/2026; fonte primária não declarada.',
    'user_list_2026-07-24_v1',
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
  select string_to_array(line, ';') as fields
  from regexp_split_to_table($foods$
Arroz branco;cozido;130;2.7;28.1;0.3
Arroz integral;cozido;124;2.6;25.6;1.0
Feijão carioca;cozido;76;4.8;13.6;0.3
Feijão preto;cozido;77;4.5;14.0;0.5
Lentilha;cozida;93;6.3;16.3;0.5
Grão-de-bico;cozido;121;7.0;21.0;2.0
Ervilha;cozida;81;5.0;14.0;0.4
Milho verde;cozido;98;3.4;21.0;0.6
Pipoca;estourada;387;12.9;77.9;4.5
Aveia em flocos;bruta;394;13.2;67.7;8.4
Farelo de aveia;bruto;246;17.3;50.8;7.0
Pão francês;assado;270;8.0;56.0;1.0
Pão de forma;assado;280;9.0;49.0;4.0
Pão integral;assado;253;9.0;49.0;3.0
Pão de queijo;assado;363;5.0;33.0;18.0
Macarrão;cozido;138;4.8;28.0;0.7
Mandioca;cozida;125;0.6;30.0;0.3
Farinha de mandioca;bruta;360;1.2;87.0;0.3
Tapioca;preparada;240;0.5;60.0;0.1
Batata;cozida;86;1.7;19.0;0.1
Batata-doce;cozida;86;1.6;20.0;0.1
Inhame;cozido;101;1.5;23.0;0.2
Cará;cozido;87;1.7;19.5;0.2
Batata-baroa;cozida;80;1.5;18.0;0.1
Cuscuz nordestino;cozido;112;3.8;23.0;0.2
Peito de frango;grelhado;165;31.0;0;3.6
Coxa de frango;cozida;209;26.0;0;11.0
Carne moída;refogada;219;24.0;0;13.0
Patinho;cozido;163;26.0;0;6.0
Alcatra;grelhada;163;24.0;0;6.6
Músculo;cozido;150;26.0;0;4.0
Acém;cozido;215;26.0;0;12.0
Costela bovina;assada;410;22.0;0;36.0
Lombo suíno;assado;198;28.0;0;8.0
Tilápia;grelhada;128;26.0;0;2.7
Sardinha;grelhada;208;24.0;0;11.0
Atum em conserva;em água;108;24.0;0;0.8
Bacalhau;cozido;105;23.0;0;0.9
Camarão;cozido;99;24.0;0.2;0.3
Ovo de galinha;cozido;155;13.0;1.1;11.0
Clara de ovo;cozida;52;11.0;0.7;0.2
Gema de ovo;cozida;322;16.0;3.6;27.0
Presunto;processado;145;17.0;1.5;8.0
Mortadela;processada;270;12.0;3.0;23.0
Calabresa;processada;320;14.0;4.0;27.0
Leite integral;líquido;61;3.2;4.8;3.3
Leite desnatado;líquido;35;3.4;5.0;0.2
Iogurte natural;líquido;51;4.1;4.7;1.5
Queijo minas frescal;fresco;240;17.0;3.2;17.0
Queijo mussarela;fresco;280;22.0;3.0;20.0
Queijo prato;fresco;360;23.0;3.0;28.0
Requeijão;cremoso;257;9.0;3.0;23.0
Manteiga;temperatura ambiente;717;0.9;0.1;81.0
Queijo cottage;fresco;98;11.0;3.4;4.3
Leite condensado;líquido;321;7.0;55.0;8.0
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
Pêssego;in natura;39;0.9;9.5;0.3
Limão;in natura;29;1.1;9.3;0.3
Abacate;in natura;160;2.0;9.0;15.0
Açaí polpa;congelado;58;0.8;6.2;3.7
Maracujá;in natura;97;2.2;21.0;0.7
Caju;in natura;43;1.0;10.0;0.4
Kiwi;in natura;61;1.1;15.0;0.5
Figo;in natura;74;0.8;19.0;0.3
Caqui;in natura;71;0.6;19.0;0.2
Jabuticaba;in natura;45;0.6;12.0;0.1
Pitanga;in natura;41;0.9;10.0;0.1
Tomate;in natura;21;1.1;4.7;0.2
Cebola;in natura;40;1.1;9.3;0.1
Alho;in natura;149;6.4;33.0;0.5
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
Acelga;cozida;20;1.8;4.0;0.1
Almeirão;in natura;19;1.5;4.0;0.2
Mostarda;in natura;27;2.7;4.9;0.5
Castanha do Brasil;in natura;656;14.0;12.0;66.0
Castanha de caju;in natura;553;18.0;30.0;44.0
Amendoim;torrado;567;26.0;16.0;49.0
Amêndoa;in natura;579;21.0;22.0;50.0
Linhaça;em grão;534;18.0;29.0;42.0
Chia;em grão;486;17.0;42.0;31.0
Azeite de oliva;líquido;884;0;0;100.0
Óleo de soja;líquido;884;0;0;100.0
Manteiga de amendoim;cremosa;588;25.0;20.0;50.0
Margarina;temperatura ambiente;720;0.2;0.7;81.0
Açúcar refinado;cristal;387;0;100.0;0
Açúcar mascavo;cristal;380;0.5;95.0;0.1
Mel;líquido;304;0.3;82.0;0
Achocolatado em pó;pó;400;5.0;87.0;4.0
Doce de leite;cremoso;306;6.0;55.0;8.0
Goiabada;cremosa;290;0.5;70.0;0.5
Brigadeiro;preparado;400;6.0;60.0;16.0
Bolo de chocolate;assado;360;5.0;50.0;16.0
Biscoito maisena;assado;443;7.0;75.0;12.0
Biscoito cream cracker;assado;432;10.0;71.0;11.0
Café preto;coado;2;0.3;0;0
Suco de laranja natural;líquido;45;0.7;10.0;0.2
Chá mate;infusão;4;0.1;0.8;0.1
Refrigerante cola;líquido;42;0;11.0;0
Cerveja;líquido;43;0.5;3.6;0
Vinho tinto;líquido;85;0.1;2.6;0
Água de coco;líquido;19;0.7;3.7;0.2
Catchup;cremoso;112;1.7;27.0;0.1
Maionese;cremosa;680;1.0;0.6;75.0
Molho de tomate;cozido;35;1.6;7.5;0.2
$foods$, E'\r?\n') as line
  where btrim(line) <> ''
),
parsed as (
  select
    'user-' || md5(lower(btrim(fields[1])) || '|' || lower(btrim(fields[2]))) as source_food_code,
    btrim(fields[1]) as name,
    btrim(fields[2]) as preparation_state,
    fields[3]::numeric as energy_kcal,
    fields[4]::numeric as protein_g,
    fields[5]::numeric as carbohydrate_g,
    fields[6]::numeric as fat_g
  from raw
  where cardinality(fields) = 6
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
    review_status
  )
  select
    source.id,
    parsed.source_food_code,
    parsed.name,
    parsed.preparation_state,
    'food',
    'Lista fornecida pelo usuário em 24/07/2026; valores declarados por 100 g',
    date '2026-07-24',
    1,
    'pending_review'
  from parsed
  cross join source
  on conflict (source_id, source_food_code) where organization_id is null
  do update set
    name = excluded.name,
    preparation_state = excluded.preparation_state,
    is_active = true,
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
join parsed on parsed.source_food_code = food.source_food_code
cross join source
cross join lateral (
  values
    ('energy_kcal'::text, parsed.energy_kcal),
    ('protein_g'::text, parsed.protein_g),
    ('carbohydrate_g'::text, parsed.carbohydrate_g),
    ('fat_g'::text, parsed.fat_g)
) as value(code, amount)
join public.nutrients nutrient on nutrient.code = value.code
on conflict (food_id, nutrient_id) do update set
  amount_per_100g = excluded.amount_per_100g,
  data_version = excluded.data_version;
