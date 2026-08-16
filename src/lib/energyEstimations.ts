import type { BiologicalSex, EnergyProtocol, NutritionalEstimateInput, NutritionalEstimateResult } from '../types'

export const PROTOCOL_LABELS: Record<EnergyProtocol, string> = {
  mifflin_st_jeor: 'Mifflin-St Jeor (1990)',
  harris_benedict: 'Harris-Benedict (Roza & Shizgal 1984)',
  eer_iom: 'EER / IOM (2006)',
  tinsley: 'Tinsley (2018 - Atletas/Praticantes)',
}

export const PROTOCOL_DESCRIPTIONS: Record<EnergyProtocol, string> = {
  mifflin_st_jeor: 'Padrão ouro para indivíduos saudáveis de peso normal a sobrepeso.',
  harris_benedict: 'Protocolo clássico revisado, amplamente utilizado na prática clínica na América Latina.',
  eer_iom: 'Equação de Requisito Energético Estimado do Institute of Medicine (EUA).',
  tinsley: 'Otimizado para praticantes de musculação e atletas com maior massa magra.',
}

export const ACTIVITY_LEVEL_PRESETS = [
  { factor: 1.2, label: 'Sedentário (pouco ou nenhum exercício)' },
  { factor: 1.375, label: 'Levemente ativo (exercício leve 1 a 3 dias/semana)' },
  { factor: 1.55, label: 'Moderadamente ativo (exercício moderado 3 a 5 dias/semana)' },
  { factor: 1.725, label: 'Muito ativo (exercício pesado 6 a 7 dias/semana)' },
  { factor: 1.9, label: 'Extremamente ativo (exercício pesado diário ou trabalho físico)' },
]

export function calculateEnergyEstimate(input: NutritionalEstimateInput): NutritionalEstimateResult {
  const weight = Math.max(1, input.currentWeightKg)
  const heightCm = Math.max(30, input.heightCm)
  const age = Math.max(0, input.ageYears)
  const sex: BiologicalSex = input.biologicalSex === 'male' ? 'male' : 'female'
  const activity = Math.max(1, input.activityFactor || 1.2)

  let bmr = 0
  let tee = 0

  if (input.protocol === 'mifflin_st_jeor') {
    bmr = 10 * weight + 6.25 * heightCm - 5 * age + (sex === 'male' ? 5 : -161)
    tee = bmr * activity
  } else if (input.protocol === 'harris_benedict') {
    if (sex === 'male') {
      bmr = 88.362 + 13.397 * weight + 4.799 * heightCm - 5.677 * age
    } else {
      bmr = 447.593 + 9.247 * weight + 3.098 * heightCm - 4.330 * age
    }
    tee = bmr * activity
  } else if (input.protocol === 'eer_iom') {
    const heightM = heightCm / 100
    if (sex === 'male') {
      bmr = 662 - 9.53 * age + 1.0 * (15.91 * weight + 539.6 * heightM)
      tee = 662 - 9.53 * age + activity * (15.91 * weight + 539.6 * heightM)
    } else {
      bmr = 354 - 6.91 * age + 1.0 * (9.36 * weight + 726 * heightM)
      tee = 354 - 6.91 * age + activity * (9.36 * weight + 726 * heightM)
    }
  } else if (input.protocol === 'tinsley') {
    bmr = 24.8 * weight + 10
    tee = bmr * activity
  } else {
    bmr = 10 * weight + 6.25 * heightCm - 5 * age + (sex === 'male' ? 5 : -161)
    tee = bmr * activity
  }

  return {
    basalMetabolicRate: Math.round(bmr * 10) / 10,
    totalEnergyExpenditure: Math.round(tee * 10) / 10,
    protocol: input.protocol,
  }
}
