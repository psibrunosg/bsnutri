export type ModelDimensions = { approaches:string[]; objectives:string[]; restrictions:string[]; preferences:string[]; contexts:string[] }
export type ModelRules = { targets:Record<string,number>; guidance:string[] }
export type BuiltInPlanModel = { id:string; name:string; summary:string; dimensions:ModelDimensions; rules:ModelRules }

const dimensions=(approach:string,objective:string,contexts:string[]=[]):ModelDimensions=>({approaches:[approach],objectives:[objective],restrictions:[],preferences:[],contexts})
const rules=(targets:Record<string,number>,...guidance:string[]):ModelRules=>({targets,guidance})

export const builtInPlanModels:BuiltInPlanModel[]=[
  {id:'balanced-brazilian',name:'Alimentação brasileira equilibrada',summary:'Estrutura culturalmente familiar para revisão clínica.',dimensions:dimensions('Brasileira equilibrada','Saúde e rotina',['cultura brasileira']),rules:rules({energyKcal:2000,proteinG:100,carbohydrateG:250,fatG:67,fiberG:30,waterMl:2000},'Priorize alimentos in natura e preparações caseiras.')},
  {id:'mediterranean',name:'Mediterrânea',summary:'Base vegetal, azeite e alimentos minimamente processados.',dimensions:dimensions('Mediterrânea','Saúde cardiovascular'),rules:rules({energyKcal:2000,proteinG:100,carbohydrateG:225,fatG:78,fiberG:30,waterMl:2000},'Ajuste porções e preferências antes de publicar.')},
  {id:'dash',name:'DASH',summary:'Estrutura com atenção a sódio e qualidade alimentar.',dimensions:dimensions('DASH','Controle pressórico'),rules:rules({energyKcal:2000,proteinG:100,carbohydrateG:250,fatG:67,fiberG:30,waterMl:2000},'Defina limite de sódio na revisão técnica.')},
  {id:'vegetarian',name:'Vegetariana',summary:'Modelo sem carnes para adaptar ao padrão alimentar.',dimensions:dimensions('Vegetariana','Saúde e rotina'),rules:rules({energyKcal:2000,proteinG:105,carbohydrateG:245,fatG:68,fiberG:35,waterMl:2000},'Revise fontes proteicas e micronutrientes prioritários.')},
  {id:'vegan',name:'Vegana',summary:'Modelo vegetal integral para adaptação profissional.',dimensions:dimensions('Vegana','Saúde e rotina'),rules:rules({energyKcal:2000,proteinG:110,carbohydrateG:250,fatG:64,fiberG:38,waterMl:2000},'Revise suplementação e nutrientes críticos quando aplicável.')},
  {id:'weight-loss',name:'Emagrecimento',summary:'Ponto de partida para metas de redução de peso.',dimensions:dimensions('Flexível','Emagrecimento'),rules:rules({energyKcal:1700,proteinG:120,carbohydrateG:170,fatG:58,fiberG:30,waterMl:2200},'A proposta exige ajuste individual e revisão profissional.')},
  {id:'hypertrophy',name:'Hipertrofia',summary:'Estrutura inicial de maior aporte energético e proteico.',dimensions:dimensions('Flexível','Hipertrofia'),rules:rules({energyKcal:2600,proteinG:150,carbohydrateG:335,fatG:73,fiberG:30,waterMl:3000},'Distribua refeições conforme treino e rotina.')},
  {id:'performance',name:'Desempenho',summary:'Modelo para organizar energia e carboidratos no treino.',dimensions:dimensions('Esportiva','Desempenho'),rules:rules({energyKcal:2800,proteinG:140,carbohydrateG:385,fatG:75,fiberG:30,waterMl:3000},'Ajuste disponibilidade energética ao volume de treino.')},
  {id:'glycemic',name:'Controle glicêmico',summary:'Estrutura com foco em qualidade e distribuição de carboidratos.',dimensions:dimensions('Flexível','Controle glicêmico'),rules:rules({energyKcal:1900,proteinG:115,carbohydrateG:190,fatG:72,fiberG:35,waterMl:2200},'Revise distribuição de carboidratos e fibras.')},
  {id:'low-cost',name:'Baixo custo',summary:'Combinações acessíveis e adaptáveis ao orçamento.',dimensions:dimensions('Brasileira equilibrada','Baixo custo',['baixo custo']),rules:rules({energyKcal:2000,proteinG:100,carbohydrateG:255,fatG:65,fiberG:30,waterMl:2000},'Priorize alimentos disponíveis na região.')},
  {id:'busy-routine',name:'Rotina corrida',summary:'Refeições simples para pouco tempo de preparo.',dimensions:dimensions('Flexível','Adesão',['rotina corrida']),rules:rules({energyKcal:2000,proteinG:110,carbohydrateG:240,fatG:70,fiberG:30,waterMl:2200},'Planeje preparos, compras e alternativas rápidas.')},
]

export function matchesModel(model:{dimensions:ModelDimensions},filters:Partial<ModelDimensions>){
  return (Object.keys(filters) as (keyof ModelDimensions)[]).every(key=>!filters[key]?.length||filters[key]!.some(value=>model.dimensions[key].includes(value)))
}
