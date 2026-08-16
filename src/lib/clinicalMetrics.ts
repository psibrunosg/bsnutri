import type { BiologicalSex } from '../types'

export interface BodyMassIndexCategory {
  label: string
  tone: 'low' | 'healthy' | 'warning' | 'high' | 'critical'
}

/**
 * Idade em anos completos. Nunca assume um valor padrão: sem data de nascimento
 * válida a idade permanece ausente e o consumidor precisa exigir o dado.
 */
export function ageInYears(birthDate: string | null | undefined, today: Date): number | null {
  if (!birthDate) return null
  const born = new Date(`${birthDate}T12:00:00`)
  if (Number.isNaN(born.getTime())) return null
  let age = today.getFullYear() - born.getFullYear()
  const monthDelta = today.getMonth() - born.getMonth()
  if (monthDelta < 0 || (monthDelta === 0 && today.getDate() < born.getDate())) age -= 1
  if (age < 0) return null
  return age
}

export function bodyMassIndex(weightKg: number | null | undefined, heightCm: number | null | undefined): number | null {
  if (!weightKg || !heightCm || weightKg <= 0 || heightCm <= 0) return null
  const heightM = heightCm / 100
  return weightKg / (heightM * heightM)
}

export function bodyMassIndexCategory(index: number | null): BodyMassIndexCategory | null {
  if (index === null || !Number.isFinite(index) || index <= 0) return null
  if (index < 18.5) return { label: 'Abaixo do peso', tone: 'low' }
  if (index < 25) return { label: 'Eutrofia', tone: 'healthy' }
  if (index < 30) return { label: 'Sobrepeso', tone: 'warning' }
  if (index < 35) return { label: 'Obesidade I', tone: 'high' }
  return { label: 'Obesidade II+', tone: 'critical' }
}

export function waistHipRatio(waistCm: number | null | undefined, hipCm: number | null | undefined): number | null {
  if (!waistCm || !hipCm || waistCm <= 0 || hipCm <= 0) return null
  return waistCm / hipCm
}

/** Recebe medidas da mais recente para a mais antiga. */
export function weightDelta(measurements: { weight_kg: number | null }[]): number | null {
  if (measurements.length < 2) return null
  const [latest, previous] = measurements
  if (latest.weight_kg === null || previous.weight_kg === null) return null
  return latest.weight_kg - previous.weight_kg
}

export function isEstimateInputComplete(input: {
  weightKg: number | null
  heightCm: number | null
  ageYears: number | null
  biologicalSex: BiologicalSex | null
}): boolean {
  if (input.weightKg === null || input.weightKg <= 0) return false
  if (input.heightCm === null || input.heightCm <= 0) return false
  if (input.ageYears === null || input.ageYears < 0) return false
  return input.biologicalSex === 'female' || input.biologicalSex === 'male'
}
