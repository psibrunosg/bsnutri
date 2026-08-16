import { jsPDF } from "jspdf";
import autoTable from "jspdf-autotable";
import type { Food, Patient, PatientPlan } from "./types";
import { WEEK_DAYS, MEAL_TYPES, planTotals } from "./types";

const GREEN: [number, number, number] = [74, 103, 65];
const DARK: [number, number, number] = [34, 48, 28];
const CREAM: [number, number, number] = [250, 248, 242];
const AMBER: [number, number, number] = [217, 164, 74];

export function exportPlanPdf(plan: PatientPlan, patient: Patient, foods: Food[]) {
  const doc = new jsPDF({ unit: "mm", format: "a4" });
  const pageW = doc.internal.pageSize.getWidth();
  const totals = planTotals(plan.plan, foods);

  // Header
  doc.setFillColor(...GREEN);
  doc.rect(0, 0, pageW, 26, "F");
  doc.setTextColor(250, 248, 242);
  doc.setFontSize(16);
  doc.setFont("helvetica", "bold");
  doc.text("BSNutri", 14, 11);
  doc.setFontSize(9);
  doc.setFont("helvetica", "normal");
  doc.text("Plano alimentar semanal", 14, 18);
  doc.setFontSize(9);
  doc.text(`Emitido em ${new Date().toLocaleDateString("pt-BR")}`, pageW - 14, 18, { align: "right" });

  // Patient info
  doc.setTextColor(...DARK);
  doc.setFontSize(13);
  doc.setFont("helvetica", "bold");
  doc.text(patient.name, 14, 36);
  doc.setFontSize(10);
  doc.setFont("helvetica", "normal");
  doc.setTextColor(110, 105, 92);
  doc.text(`${plan.name}  ·  Meta diária aproximada: ${totals.kcal} kcal`, 14, 43);

  // Macro strip
  const macros = [
    ["Calorias", `${totals.kcal} kcal`],
    ["Proteínas", `${totals.protein} g`],
    ["Carboidratos", `${totals.carbs} g`],
    ["Gorduras", `${totals.fat} g`],
  ];
  let x = 14;
  for (const [label, value] of macros) {
    doc.setFillColor(...CREAM);
    doc.roundedRect(x, 48, 44, 16, 2, 2, "F");
    doc.setFontSize(7.5);
    doc.setTextColor(133, 89, 29);
    doc.text(label.toUpperCase(), x + 4, 54);
    doc.setFontSize(10.5);
    doc.setTextColor(...DARK);
    doc.setFont("helvetica", "bold");
    doc.text(value, x + 4, 60);
    doc.setFont("helvetica", "normal");
    x += 48;
  }

  // Weekly table
  const head = [["Refeição", ...WEEK_DAYS.map((d) => d.slice(0, 3).toUpperCase())]];
  const body = MEAL_TYPES.map((meal) => [
    meal,
    ...WEEK_DAYS.map((day) => {
      const items = plan.plan[day]?.[meal] ?? [];
      if (!items.length) return "—";
      return items
        .map((it) => {
          const f = foods.find((x) => x.id === it.foodId);
          return f ? `${f.name} (${it.qty > 1 ? it.qty + "x " : ""}${f.unit})` : "";
        })
        .join("\n");
    }),
  ]);

  autoTable(doc, {
    startY: 70,
    head,
    body,
    styles: { fontSize: 7.4, cellPadding: 2.2, textColor: DARK, valign: "top" },
    headStyles: { fillColor: GREEN, textColor: [250, 248, 242], fontStyle: "bold", fontSize: 7.8 },
    alternateRowStyles: { fillColor: CREAM },
    columnStyles: { 0: { fontStyle: "bold", cellWidth: 26, textColor: GREEN } },
    margin: { left: 14, right: 14 },
  });

  // Notes
  const finalY = (doc as unknown as { lastAutoTable: { finalY: number } }).lastAutoTable.finalY;
  if (plan.notes) {
    doc.setFontSize(9);
    doc.setTextColor(110, 105, 92);
    const lines = doc.splitTextToSize(`Observações do profissional: ${plan.notes}`, pageW - 28);
    doc.text(lines, 14, finalY + 8);
  }

  // Footer
  doc.setFillColor(...AMBER);
  doc.rect(0, 291, pageW, 1.2, "F");
  doc.setFontSize(8);
  doc.setTextColor(133, 89, 29);
  doc.text("Documento gerado pelo BSNutri · Uso pessoal do paciente", pageW / 2, 295, { align: "center" });

  doc.save(`plano-alimentar-${patient.name.toLowerCase().replace(/\s+/g, "-")}.pdf`);
}

export function exportSubstitutionMapPdf(patient: Patient, foods: Food[]) {
  const doc = new jsPDF({ unit: "mm", format: "a4" });
  const pageW = doc.internal.pageSize.getWidth();
  doc.setFillColor(...GREEN);
  doc.rect(0, 0, pageW, 26, "F");
  doc.setTextColor(250, 248, 242);
  doc.setFont("helvetica", "bold");
  doc.setFontSize(16);
  doc.text("BSNutri", 14, 11);
  doc.setFont("helvetica", "normal");
  doc.setFontSize(9);
  doc.text("Mapa de substituições", 14, 18);

  doc.setTextColor(...DARK);
  doc.setFontSize(13);
  doc.setFont("helvetica", "bold");
  doc.text(patient.name, 14, 36);
  doc.setFont("helvetica", "normal");
  doc.setFontSize(9.5);
  doc.setTextColor(110, 105, 92);
  doc.text("Se não tiver um alimento do plano, troque por qualquer outro do mesmo grupo:", 14, 43);

  const groups = [...new Set(foods.map((f) => f.group))];
  autoTable(doc, {
    startY: 50,
    head: [["Grupo", "Opções equivalentes"]],
    body: groups.map((g) => [g, foods.filter((f) => f.group === g).map((f) => `${f.name} — ${f.unit}`).join("\n")]),
    styles: { fontSize: 8.2, cellPadding: 2.6, textColor: DARK, valign: "top" },
    headStyles: { fillColor: GREEN, textColor: [250, 248, 242], fontStyle: "bold" },
    alternateRowStyles: { fillColor: CREAM },
    columnStyles: { 0: { fontStyle: "bold", cellWidth: 32, textColor: GREEN } },
    margin: { left: 14, right: 14 },
  });

  doc.setFillColor(...AMBER);
  doc.rect(0, 291, pageW, 1.2, "F");
  doc.setFontSize(8);
  doc.setTextColor(133, 89, 29);
  doc.text("Documento gerado pelo BSNutri · Uso pessoal do paciente", pageW / 2, 295, { align: "center" });

  doc.save(`mapa-de-substituicoes-${patient.name.toLowerCase().replace(/\s+/g, "-")}.pdf`);
}
