import { useCallback, useEffect, useMemo, useState } from 'react'
import { createSupabasePatientDataSource, type PatientDataSource, type PatientSummary } from './patients'

export interface PatientDirectory {
  patients: PatientSummary[]
  loading: boolean
  error: string
  reload: () => Promise<void>
}

export function usePatientDirectory(organizationId: string, source?: PatientDataSource): PatientDirectory {
  const dataSource = useMemo(() => source ?? createSupabasePatientDataSource(), [source])
  const [patients, setPatients] = useState<PatientSummary[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')

  const reload = useCallback(async () => {
    setLoading(true)
    const result = await dataSource.listPatients(organizationId)
    if (result.error) {
      setError(result.error.message)
      setPatients([])
    } else {
      setError('')
      setPatients(result.data ?? [])
    }
    setLoading(false)
  }, [dataSource, organizationId])

  useEffect(() => { void reload() }, [reload])

  return { patients, loading, error, reload }
}
