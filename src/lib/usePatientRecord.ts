import { useCallback, useEffect, useState } from 'react'
import { supabase } from './supabase'
import type { NutritionalEstimateRow } from '../types'

export interface AssessmentRow {
  id: string
  assessed_at: string
  objective: string | null
  food_preferences: string | null
  food_restrictions: string | null
  allergies: string | null
  clinical_notes: string | null
}

export interface AnthropometryRow {
  id: string
  measured_at: string
  weight_kg: number | null
  height_cm: number | null
  body_fat_percent: number | null
  waist_cm: number | null
  hip_cm: number | null
  arm_cm: number | null
  notes: string | null
}

export interface LabResultRow {
  id: string
  collected_on: string
  test_name: string
  result_value: number | null
  unit: string | null
  reference_range: string | null
  notes: string | null
  attachment_name: string | null
  attachment_url: string | null
}

export interface PatientGoalRow {
  id: string
  kind: string
  title: string
  target_value: number | null
  target_unit: string | null
  active: boolean
  starts_on: string
  ends_on: string | null
}

export interface ConsultationSummaryRow {
  id: string
  summary: string
  created_at: string
}

export interface ClinicalDraftRow {
  id: string
  kind: 'summary' | 'guidance' | 'plan_structure'
  body: string
  status: 'draft' | 'approved' | 'discarded'
  created_at: string
}

export interface PlanRow {
  id: string
  title: string
  status: string
  starts_on: string | null
  ends_on: string | null
  updated_at: string
  published_at: string | null
}

export interface PatientRecord {
  assessments: AssessmentRow[]
  measurements: AnthropometryRow[]
  labs: LabResultRow[]
  goals: PatientGoalRow[]
  summaries: ConsultationSummaryRow[]
  drafts: ClinicalDraftRow[]
  estimates: NutritionalEstimateRow[]
  plans: PlanRow[]
}

const EMPTY_RECORD: PatientRecord = {
  assessments: [],
  measurements: [],
  labs: [],
  goals: [],
  summaries: [],
  drafts: [],
  estimates: [],
  plans: [],
}

/** Cada módulo falha isoladamente: um erro parcial não derruba a ficha inteira. */
export function usePatientRecord(patientId: string) {
  const [record, setRecord] = useState<PatientRecord>(EMPTY_RECORD)
  const [loading, setLoading] = useState(true)
  const [errors, setErrors] = useState<string[]>([])

  const reload = useCallback(async () => {
    setLoading(true)
    const [assessments, measurements, labs, goals, summaries, drafts, estimates, plans] = await Promise.all([
      supabase.from('assessments').select('id,assessed_at,objective,food_preferences,food_restrictions,allergies,clinical_notes').eq('patient_id', patientId).order('assessed_at', { ascending: false }),
      supabase.from('anthropometry').select('id,measured_at,weight_kg,height_cm,body_fat_percent,waist_cm,hip_cm,arm_cm,notes').eq('patient_id', patientId).order('measured_at', { ascending: false }),
      supabase.from('lab_results').select('id,collected_on,test_name,result_value,unit,reference_range,notes,attachment_name,attachment_url').eq('patient_id', patientId).order('collected_on', { ascending: false }),
      supabase.from('patient_goals').select('id,kind,title,target_value,target_unit,active,starts_on,ends_on').eq('patient_id', patientId).order('created_at', { ascending: false }),
      supabase.from('consultation_summaries').select('id,summary,created_at').eq('patient_id', patientId).order('created_at', { ascending: false }),
      supabase.from('clinical_drafts').select('id,kind,body,status,created_at').eq('patient_id', patientId).order('created_at', { ascending: false }),
      supabase.from('nutritional_estimates').select('*').eq('patient_id', patientId).order('calculated_on', { ascending: false }),
      supabase.from('plans').select('id,title,status,starts_on,ends_on,updated_at,published_at').eq('patient_id', patientId).order('updated_at', { ascending: false }),
    ])

    const collected: string[] = []
    const push = (label: string, message: string | undefined) => { if (message) collected.push(`${label}: ${message}`) }
    push('Avaliações', assessments.error?.message)
    push('Antropometria', measurements.error?.message)
    push('Exames', labs.error?.message)
    push('Metas', goals.error?.message)
    push('Resumos', summaries.error?.message)
    push('Rascunhos', drafts.error?.message)
    push('Estimativas', estimates.error?.message)
    push('Planos', plans.error?.message)

    setRecord({
      assessments: (assessments.data ?? []) as AssessmentRow[],
      measurements: (measurements.data ?? []) as AnthropometryRow[],
      labs: (labs.data ?? []) as LabResultRow[],
      goals: (goals.data ?? []) as PatientGoalRow[],
      summaries: (summaries.data ?? []) as ConsultationSummaryRow[],
      drafts: (drafts.data ?? []) as ClinicalDraftRow[],
      estimates: (estimates.data ?? []) as unknown as NutritionalEstimateRow[],
      plans: (plans.data ?? []) as PlanRow[],
    })
    setErrors(collected)
    setLoading(false)
  }, [patientId])

  useEffect(() => { void reload() }, [reload])

  return { record, loading, errors, reload }
}
