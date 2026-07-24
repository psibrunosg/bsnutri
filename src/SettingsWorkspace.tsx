import { useEffect, useMemo, useState } from 'react'
import { parseCatalogImport } from './lib/catalog'
import { supabase } from './lib/supabase'

type FoodSource = { id:string; name:string; code:string; dataset_version:string }
type CatalogEntry = { name:string; preparation_state:string }

export function SettingsWorkspace({organizationId}:{organizationId:string}){
  const [sources,setSources]=useState<FoodSource[]>([])
  const [foods,setFoods]=useState<CatalogEntry[]>([])
  const [sourceId,setSourceId]=useState('')
  const [text,setText]=useState('')
  const [busy,setBusy]=useState(false)
  const [message,setMessage]=useState('')
  const preview=useMemo(()=>parseCatalogImport(text,foods.map(food=>({name:food.name,preparationState:food.preparation_state}))),[text,foods])

  useEffect(()=>{void (async()=>{
    const [sourceResult,foodResult]=await Promise.all([
      supabase.from('food_sources').select('id,name,code,dataset_version').order('name'),
      supabase.from('foods').select('name,preparation_state').or(`organization_id.is.null,organization_id.eq.${organizationId}`).eq('is_active',true),
    ])
    if(sourceResult.error||foodResult.error)setMessage(sourceResult.error?.message??foodResult.error?.message??'Não foi possível carregar as configurações de importação.')
    else {setSources(sourceResult.data??[]);setFoods(foodResult.data??[])}
  })()},[organizationId])

  async function importFoods(){
    if(!sourceId||!preview.rows.length||preview.errors.length)return
    setBusy(true);setMessage('')
    const {error}=await supabase.rpc('import_catalog_foods',{target_organization_id:organizationId,target_source_id:sourceId,target_items:preview.rows.map(row=>({name:row.name,preparation_state:row.preparationState,energy_kcal:row.energyKcal,protein_g:row.proteinG,carbohydrate_g:row.carbohydrateG,fat_g:row.fatG}))})
    setBusy(false)
    if(error){setMessage(`Importação não realizada: ${error.message}`);return}
    setFoods(current=>[...current,...preview.rows.map(row=>({name:row.name,preparation_state:row.preparationState}))])
    setText('');setMessage(`${preview.rows.length} item(ns) importado(s) e pendente(s) de revisão.`)
  }

  return <section className="settings-workspace">
    <header><span className="eyebrow">Configurações</span><h2>Importação do catálogo</h2><p className="muted">Centralize aqui as importações para revisar a origem, a versão e a prévia antes de gravar.</p></header>
    {message&&<div className="notice" role="status">{message}</div>}
    <section className="panel catalog-import"><h3>Importar alimentos</h3><p className="muted">Cole CSV separado por ponto e vírgula: <code>nome;preparo;energia;proteína;carboidrato;gordura</code>.</p><label>Fonte da importação<select value={sourceId} onChange={event=>setSourceId(event.target.value)}><option value="">Selecione uma fonte</option>{sources.map(source=><option value={source.id} key={source.id}>{source.name} · {source.dataset_version}</option>)}</select></label><label>Dados para prévia<textarea aria-label="Dados para importação" value={text} onChange={event=>setText(event.target.value)} placeholder="Arroz;cozido;130;2,5;28;0,3"/></label>{Boolean(text)&&<div className="import-preview" role="status"><strong>{preview.rows.length} item(ns) pronto(s) para importar</strong>{preview.rows.length>0&&<ul>{preview.rows.map(row=><li key={`${row.name}-${row.preparationState}`}>{row.name} · {row.preparationState} · {row.energyKcal} kcal</li>)}</ul>}{preview.errors.map(error=><p key={error}>{error}</p>)}</div>}<button className="primary" disabled={busy||!sourceId||!preview.rows.length||preview.errors.length>0} onClick={()=>void importFoods()}>{busy?'Importando...':'Importar prévia validada'}</button></section>
  </section>
}
