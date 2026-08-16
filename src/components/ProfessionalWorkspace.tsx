import { useMemo } from 'react'
import { Shell } from './Shell'
import type { AppRoute } from '../lib/appRoute'
import { createSupabasePatientDataSource } from '../lib/patients'
import { usePatientDirectory } from '../lib/usePatientDirectory'
import Dashboard from '../pages/Dashboard'
import PatientDetail from '../pages/PatientDetail'
import Patients from '../pages/Patients'
import PatientWizard from '../pages/PatientWizard'
import type { WorkspaceAccess } from '../types'

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
  const directory = usePatientDirectory(workspace.organizationId, dataSource)
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
    content = <ModulePending title="Editor de plano" />
  } else if (route.page === 'templates') {
    content = <ModulePending title="Modelos de plano" />
  } else if (route.page === 'content') {
    content = <ModulePending title="Biblioteca de conteúdos" />
  }

  return (
    <Shell route={route} workspace={workspace} onNavigate={onNavigate} onLogout={onLogout}>
      {content}
    </Shell>
  )
}
