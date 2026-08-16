import { totalDay } from './nutrition'
import type { DraftSummary, EditorDay } from './planDrafts'

const GREEN: [number, number, number] = [74, 103, 65]
const DARK: [number, number, number] = [34, 48, 28]
const CREAM: [number, number, number] = [250, 248, 242]
const AMBER: [number, number, number] = [217, 164, 74]

export interface PublishedPlanDocument {
  patientName: string
  planTitle: string
  version: number
  days: EditorDay[]
  /** Somente substituições prescritas e revisadas entram no documento do paciente. */
  substitutions: { originalName: string; options: string[] }[]
}

/**
 * Substituição prescrita pelo profissional em uma versão do plano.
 * Só entra no documento do paciente quando está ativa e pertence à versão publicada.
 */
export interface PrescribedSubstitution {
  planVersionId: string
  mealItemId: string
  replacementName: string
  isActive: boolean
}

/**
 * Constrói o documento do paciente a partir de um plano.
 * Devolve `null` quando a versão não está publicada: rascunho e versão em revisão
 * nunca viram PDF entregue ao paciente.
 */
export function toPublishedPlanDocument(
  draft: DraftSummary,
  patientName: string,
  substitutions: PrescribedSubstitution[] = [],
): PublishedPlanDocument | null {
  if (!draft.locked || draft.status !== 'published') return null

  const itemNameById = new Map<string, string>()
  for (const day of draft.days) {
    for (const meal of day.meals) {
      for (const item of meal.items) itemNameById.set(item.id, item.name)
    }
  }

  const grouped = new Map<string, Set<string>>()
  for (const substitution of substitutions) {
    if (!substitution.isActive) continue
    if (substitution.planVersionId !== draft.versionId) continue
    const original = itemNameById.get(substitution.mealItemId)
    if (!original) continue
    const options = grouped.get(original) ?? new Set<string>()
    options.add(substitution.replacementName)
    grouped.set(original, options)
  }

  return {
    patientName,
    planTitle: draft.title,
    version: draft.version,
    days: draft.days,
    substitutions: [...grouped.entries()].map(([originalName, options]) => ({ originalName, options: [...options] })),
  }
}

/**
 * Monta o documento e devolve a instância, sem gravar nada. Separado do
 * salvamento para que o teste exercite a geração sem despejar PDF no disco.
 * Carrega o gerador sob demanda: o pacote inicial não paga por ele.
 */
export async function buildPublishedPlanPdf(document: PublishedPlanDocument) {
  const [{ jsPDF }, { default: autoTable }] = await Promise.all([import('jspdf'), import('jspdf-autotable')])
  const doc = new jsPDF({ unit: 'mm', format: 'a4' })
  const pageWidth = doc.internal.pageSize.getWidth()

  doc.setFillColor(...GREEN)
  doc.rect(0, 0, pageWidth, 26, 'F')
  doc.setTextColor(250, 248, 242)
  doc.setFontSize(16)
  doc.setFont('helvetica', 'bold')
  doc.text('BSNutri', 14, 11)
  doc.setFontSize(9)
  doc.setFont('helvetica', 'normal')
  doc.text(`${document.planTitle} · versão publicada ${document.version}`, 14, 18)
  doc.text(`Emitido em ${new Date().toLocaleDateString('pt-BR')}`, pageWidth - 14, 18, { align: 'right' })

  doc.setTextColor(...DARK)
  doc.setFontSize(13)
  doc.setFont('helvetica', 'bold')
  doc.text(document.patientName, 14, 36)

  let cursor = 44
  for (const day of document.days) {
    const totals = totalDay(day.meals)
    autoTable(doc, {
      startY: cursor,
      head: [[day.label, `${Math.round(totals.energyKcal)} kcal · P ${Math.round(totals.proteinG)} g · C ${Math.round(totals.carbohydrateG)} g · G ${Math.round(totals.fatG)} g`]],
      body: day.meals.map((meal) => [
        meal.name,
        meal.items.length ? meal.items.map((item) => `${item.name} — ${item.grams} g`).join('\n') : '—',
      ]),
      styles: { fontSize: 8, cellPadding: 2.2, textColor: DARK, valign: 'top' },
      headStyles: { fillColor: GREEN, textColor: [250, 248, 242], fontStyle: 'bold', fontSize: 8.4 },
      alternateRowStyles: { fillColor: CREAM },
      columnStyles: { 0: { fontStyle: 'bold', cellWidth: 40, textColor: GREEN } },
      margin: { left: 14, right: 14 },
    })
    cursor = (doc as unknown as { lastAutoTable: { finalY: number } }).lastAutoTable.finalY + 6
  }

  if (document.substitutions.length) {
    autoTable(doc, {
      startY: cursor,
      head: [['Substituição prescrita', 'Opções revisadas']],
      body: document.substitutions.map((item) => [item.originalName, item.options.join('\n')]),
      styles: { fontSize: 8, cellPadding: 2.2, textColor: DARK, valign: 'top' },
      headStyles: { fillColor: AMBER, textColor: [34, 48, 28], fontStyle: 'bold' },
      alternateRowStyles: { fillColor: CREAM },
      columnStyles: { 0: { fontStyle: 'bold', cellWidth: 50 } },
      margin: { left: 14, right: 14 },
    })
  }

  doc.setFillColor(...AMBER)
  doc.rect(0, 291, pageWidth, 1.2, 'F')
  doc.setFontSize(8)
  doc.setTextColor(133, 89, 29)
  doc.text('Documento gerado pelo BSNutri · versão publicada', pageWidth / 2, 295, { align: 'center' })

  return doc
}

export function publishedPlanFileName(patientName: string): string {
  const slug = patientName.toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, '').replace(/[^a-z0-9]+/g, '-').replace(/(^-|-$)/g, '')
  return `plano-alimentar-${slug || 'paciente'}.pdf`
}

export async function exportPublishedPlanPdf(document: PublishedPlanDocument): Promise<void> {
  const doc = await buildPublishedPlanPdf(document)
  doc.save(publishedPlanFileName(document.patientName))
}
