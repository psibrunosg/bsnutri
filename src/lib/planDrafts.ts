import { emptyNutrients, type Meal, type Nutrients } from './nutrition'

export type EditorDay = { id: string; label: string; kind: string; meals: Meal[] }
type PlanItemRow = { id: string; description: string; grams: number; nutrient_snapshot: Partial<Nutrients> | null }
type PlanMealRow = { id: string; label: string; position: number; meal_items: PlanItemRow[] }
type PlanDayRow = { id: string; label: string; kind: string; day_index: number; meals: PlanMealRow[] }
type PlanVersionRow = { id: string; version_no: number; targets?: Record<string,number>; locked_at?: string | null; plan_days: PlanDayRow[] }
export type PlanRow = { id: string; patient_id: string; title: string; status?: string; updated_at: string; plan_versions: PlanVersionRow[] }
export type DraftSummary = { id: string; patientId: string; title: string; status: string; updatedAt: string; versionId: string; version: number; targets: Record<string,number>; locked: boolean; days: EditorDay[] }

export function mapDraftRows(rows: PlanRow[]): DraftSummary[] {
  return rows.map(plan=>{
    const version=[...(plan.plan_versions??[])].sort((a,b)=>b.version_no-a.version_no)[0]
    const days=[...(version?.plan_days??[])].sort((a,b)=>a.day_index-b.day_index).map(day=>({
      id:day.id,label:day.label,kind:day.kind,
      meals:[...(day.meals??[])].sort((a,b)=>a.position-b.position).map(meal=>({
        id:meal.id,name:meal.label,
        items:[...(meal.meal_items??[])].map(item=>({id:item.id,name:item.description,grams:Number(item.grams),nutrientsPer100g:{...emptyNutrients(),...(item.nutrient_snapshot??{})}})),
      })),
    }))
    return{id:plan.id,patientId:plan.patient_id,title:plan.title,status:plan.status??'draft',updatedAt:plan.updated_at,versionId:version?.id??'',version:version?.version_no??0,targets:version?.targets??{},locked:Boolean(version?.locked_at),days}
  })
}
