import { useState } from 'react'
import { Archive } from 'lucide-react'
import {
  clearLegacyStore,
  importLegacyPatients,
  LEGACY_PROVENANCE,
  type LegacyImportReport,
  type LegacyPreview,
} from '../lib/legacyImport'
import type { PatientDataSource } from '../lib/patients'

export interface LegacyImportBannerProps {
  preview: LegacyPreview
  organizationId: string
  dataSource: PatientDataSource
  onImported: () => Promise<void>
  onDismiss: () => void
}

export function LegacyImportBanner({ preview, organizationId, dataSource, onImported, onDismiss }: LegacyImportBannerProps) {
  const [busy, setBusy] = useState(false)
  const [report, setReport] = useState<LegacyImportReport | null>(null)
  const [confirmingClear, setConfirmingClear] = useState(false)

  async function runImport() {
    setBusy(true)
    const result = await importLegacyPatients(preview, organizationId, dataSource)
    setBusy(false)
    setReport(result)
    await onImported()
  }

  function clearStorage() {
    clearLegacyStore(window.localStorage)
    setConfirmingClear(false)
    onDismiss()
  }

  return (
    <section className="card-warm mb-6 border-amber-200 bg-amber-50/60 p-5" aria-labelledby="legacy-import-title">
      <div className="flex items-start gap-3">
        <Archive size={18} className="mt-0.5 shrink-0 text-amber-700" aria-hidden="true" />
        <div className="min-w-0 flex-1">
          <h2 id="legacy-import-title" className="font-display text-lg font-semibold">Dados do protótipo encontrados neste navegador</h2>
          <p className="mt-1 text-sm text-muted-foreground">
            {preview.patients.length} paciente{preview.patients.length === 1 ? '' : 's'} e {preview.planCount} plano{preview.planCount === 1 ? '' : 's'} guardados localmente.
            {preview.discarded > 0 && ` ${preview.discarded} registro${preview.discarded === 1 ? '' : 's'} sem nome utilizável ${preview.discarded === 1 ? 'será ignorado' : 'serão ignorados'}.`}
            {' '}Nada é enviado sem a sua ação.
          </p>

          {preview.patients.length > 0 && (
            <ul className="mt-3 flex flex-wrap gap-1.5">
              {preview.patients.slice(0, 8).map((patient) => (
                <li key={patient.name} className="chip !bg-cream-100 text-muted-foreground">{patient.name}</li>
              ))}
              {preview.patients.length > 8 && <li className="chip !bg-cream-100 text-muted-foreground">+{preview.patients.length - 8}</li>}
            </ul>
          )}

          {report && (
            <div className="mt-4 rounded-xl border border-border bg-card p-3 text-sm" role="status">
              <p>{report.imported} paciente{report.imported === 1 ? '' : 's'} importado{report.imported === 1 ? '' : 's'} com a tag <code>{LEGACY_PROVENANCE}</code>.</p>
              {report.failures.length > 0 && (
                <ul className="mt-2 space-y-1 text-destructive">
                  {report.failures.map((failure) => <li key={failure.name}>{failure.name}: {failure.message}</li>)}
                </ul>
              )}
              <p className="mt-2 text-muted-foreground">Os planos antigos não são importados: a estrutura do protótipo não corresponde ao plano clínico versionado.</p>
            </div>
          )}

          <div className="mt-4 flex flex-wrap gap-2">
            {!report && (
              <button type="button" className="btn-primary" disabled={busy || preview.patients.length === 0} onClick={() => void runImport()}>
                {busy ? 'Importando...' : 'Importar como rascunho clínico'}
              </button>
            )}
            {report && !confirmingClear && (
              <button type="button" className="btn-ghost" onClick={() => setConfirmingClear(true)}>Apagar os dados locais</button>
            )}
            {confirmingClear && (
              <>
                <p className="w-full text-sm text-amber-800">Apagar remove os dados antigos deste navegador de forma definitiva.</p>
                <button type="button" className="btn-ghost" onClick={() => setConfirmingClear(false)}>Cancelar</button>
                <button type="button" className="btn-primary" onClick={clearStorage}>Confirmar exclusão</button>
              </>
            )}
            <button type="button" className="btn-ghost" onClick={onDismiss}>Agora não</button>
          </div>
        </div>
      </div>
    </section>
  )
}
