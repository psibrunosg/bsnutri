import { useState, useEffect } from 'react'
import type { Session } from '@supabase/supabase-js'
import { useFoodCatalog, macroKeys, macroLabels } from './lib/useFoodCatalog'
import { usePlanDraft, type Patient } from './lib/usePlanDraft'
import { NutritionCatalog } from './components/NutritionCatalog'
import { PlanEditor } from './components/PlanEditor'

export function NutritionWorkspace({ session, organizationId, patients }: { session: Session; organizationId: string; patients: Patient[] }) {
  const [tab, setTab] = useState<'catalog' | 'plan'>('catalog')
  const [message, setMessage] = useState('')
  const catalog = useFoodCatalog(organizationId, session.user.id, setMessage)
  const planDraft = usePlanDraft(organizationId, session.user.id, catalog, setMessage, setTab)

  useEffect(() => {
    const hash = window.location.hash.slice(1);
    if (hash === 'plan' || hash === 'catalog') {
      setTab(hash);
    }
  }, []);

  useEffect(() => {
    if (tab === 'plan' || tab === 'catalog') {
      const newUrl = window.location.pathname + (window.location.search ? '&' : '?') + 'tab=' + tab;
      window.history.replaceState(null, '', newUrl);
    }
  }, [tab]);

  return (
    <section className="nutrition-workspace">
      <div className="section-tabs">
        <button className={tab === 'catalog' ? 'active' : ''} onClick={() => setTab('catalog')}>
          Catálogo próprio
        </button>
        <button className={tab === 'plan' ? 'active' : ''} onClick={() => setTab('plan')}>
          Editor de plano
        </button>
      </div>
      {message && (
        <div className="notice" role="status">
          {message}
        </div>
      )}
      {planDraft.recoverableDraft && (
        <div className="notice" role="status">
          Há um rascunho local salvo em {new Date(planDraft.recoverableDraft.savedAt).toLocaleString('pt-BR')}.{' '}
          <button className="secondary" onClick={planDraft.restoreLocalDraft}>
            Restaurar
          </button>
          <button className="secondary" onClick={planDraft.discardLocalDraft}>
            Descartar
          </button>
        </div>
      )}
      {tab === 'catalog' ? (
        <NutritionCatalog
          foods={catalog.foods}
          sources={catalog.sources}
          keys={macroKeys}
          labels={macroLabels}
          busy={catalog.busy}
          preferences={catalog.foodPreferences}
          addFood={catalog.addFood}
          saveFoodPreference={catalog.saveFoodPreference}
        />
      ) : (
        <PlanEditor catalog={catalog} planDraft={planDraft} patients={patients} organizationId={organizationId} setMessage={setMessage} />
      )}
    </section>
  )
}
