import { lazy, Suspense, useMemo, useState } from 'react'
import { LegacyImportBanner } from './LegacyImportBanner'
import { Shell } from './Shell'
import { readLegacyStore } from '../lib/legacyImport'
import type { AppRoute } from '../lib/appRoute'
import { createSupabaseCatalogDataSource } from '../lib/catalogSearch'
import { createSupabasePatientDataSource } from '../lib/patients'
import { createSupabasePlanTemplateDataSource } from '../lib/planTemplates'
import { usePatientDirectory } from '../lib/usePatientDirectory'
import Dashboard from '../pages/Dashboard'
import Patients from '../pages/Patients'
import PatientWizard from '../pages/PatientWizard'
import type { WorkspaceAccess } from '../types'

// Editor, ficha, catálogo e modelos entram sob demanda: o pacote inicial cobre
// apenas autenticação, visão geral e diretório de pacientes.
const Catalog = lazy(() => import('../pages/Catalog'))
const PatientDetail = lazy(() => import('../pages/PatientDetail'))
const PlanBuilder = lazy(() => import('../pages/PlanBuilder'))
const Templates = lazy(() => import('../pages/Templates'))

function ModulePending({ title }: { title: string }) {
  return (
    <section className="card-warm p-8">
      <p className="eyebrow mb-2">BSNutri</p>
      <h1 className="font-display text-3xl font-semibold">{title}</h1>
      <p className="mt-3 max-w-xl text-sm leading-relaxed text-muted-foreground">
        Este módulo será conectado aos dados clínicos nas próximas etapas da integração.
      </p>
    </section>
  )
}

export interface ProfessionalWorkspaceProps {
  workspace: WorkspaceAccess
  userId: string
  route: AppRoute
  onNavigate: (route: AppRoute, options?: { replace?: boolean }) => void
  onLogout: () => void
}

export function ProfessionalWorkspace({ workspace, userId, route, onNavigate, onLogout }: ProfessionalWorkspaceProps) {
  const dataSource = useMemo(() => createSupabasePatientDataSource(), [])
  const catalogSource = useMemo(() => createSupabaseCatalogDataSource(), [])
  const templateSource = useMemo(() => createSupabasePlanTemplateDataSource(), [])
  const directory = usePatientDirectory(workspace.organizationId, dataSource)
  const canReviewTemplates = workspace.role === 'owner' || workspace.role === 'admin' || workspace.role === 'nutritionist'
  const [legacyPreview, setLegacyPreview] = useState(() => readLegacyStore(window.localStorage))
  const selected = directory.patients.find((patient) => patient.id === route.patientId) ?? null

  function openPatient(patientId: string) {
    onNavigate({ page: 'patient-detail', patientId })
  }

  function openPlan(planId?: string, patientId?: string) {
    onNavigate({ page: 'nutrition', ...(planId ? { planId } : {}), ...(patientId ? { patientId } : {}) })
  }

  let content = <ModulePending title="Módulo em integração" />

  if (route.page === 'dashboard') {
    content = (
      <Dashboard
        organizationId={workspace.organizationId}
        memberName={workspace.memberName}
        patients={directory.patients}
        onOpenPatient={openPatient}
        onOpenPatients={() => onNavigate({ page: 'patients' })}
        onCreatePatient={() => onNavigate({ page: 'patient-new' })}
        onOpenPlan={(planId) => openPlan(planId)}
        onOpenTemplates={() => onNavigate({ page: 'templates' })}
      />
    )
  } else if (route.page === 'patients') {
    content = (
      <Patients
        patients={directory.patients}
        loading={directory.loading}
        error={directory.error}
        onOpenPatient={openPatient}
        onCreatePatient={() => onNavigate({ page: 'patient-new' })}
      />
    )
  } else if (route.page === 'patient-new') {
    content = (
      <PatientWizard
        organizationId={workspace.organizationId}
        dataSource={dataSource}
        onCancel={() => onNavigate({ page: 'patients' })}
        onCreated={async (patientId) => {
          await directory.reload()
          onNavigate({ page: 'patient-detail', patientId })
        }}
      />
    )
  } else if (route.page === 'patient-detail') {
    content = selected ? (
      <PatientDetail
        patient={selected}
        organizationId={workspace.organizationId}
        userId={userId}
        section={route.patientSection}
        onSelectSection={(section) => onNavigate({ page: 'patient-detail', patientId: selected.id, patientSection: section }, { replace: true })}
        onBack={() => onNavigate({ page: 'patients' })}
        onDirectoryChange={directory.reload}
        onOpenPlan={(planId) => openPlan(planId, selected.id)}
      />
    ) : (
      <section className="card-warm p-8">
        <h1 className="font-display text-2xl font-semibold">{directory.loading ? 'Carregando paciente...' : 'Paciente não encontrado'}</h1>
        {!directory.loading && (
          <>
            <p className="mt-3 text-sm text-muted-foreground">Este cadastro não está disponível para o seu vínculo atual.</p>
            <button type="button" className="btn-ghost mt-5" onClick={() => onNavigate({ page: 'patients' })}>Voltar para pacientes</button>
          </>
        )}
      </section>
    )
  } else if (route.page === 'nutrition') {
    content = (
      <PlanBuilder
        organizationId={workspace.organizationId}
        userId={userId}
        patients={directory.patients}
        catalogSource={catalogSource}
        planId={route.planId}
        patientId={route.patientId}
      />
    )
  } else if (route.page === 'catalog') {
    content = <Catalog organizationId={workspace.organizationId} dataSource={catalogSource} />
  } else if (route.page === 'templates') {
    content = (
      <Templates
        organizationId={workspace.organizationId}
        dataSource={templateSource}
        patients={directory.patients}
        canReview={canReviewTemplates}
        onPlanCreated={(planId, patientId) => openPlan(planId, patientId)}
      />
    )
  } else if (route.page === 'content') {
    content = <ModulePending title="Biblioteca de conteúdos" />
  }

  return (
    <Shell route={route} workspace={workspace} onNavigate={onNavigate} onLogout={onLogout}>
      {legacyPreview && (
        <LegacyImportBanner
          preview={legacyPreview}
          organizationId={workspace.organizationId}
          dataSource={dataSource}
          onImported={directory.reload}
          onDismiss={() => setLegacyPreview(null)}
        />
      )}
      <Suspense fallback={<p className="text-sm text-muted-foreground" role="status">Carregando módulo...</p>}>
        {content}
      </Suspense>
    </Shell>
  )
}
