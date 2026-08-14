import { useState } from "react";
import { ArrowLeft, CalendarPlus, FileDown, Eye, Plus } from "lucide-react";
import { AreaChart, Area, XAxis, YAxis, Tooltip, ResponsiveContainer, CartesianGrid } from "recharts";
import { useStore } from "../lib/store";
import { imc, imcCategory, planTotals } from "../lib/types";
import { FOODS } from "../lib/data";
import { exportPlanPdf, exportEquivalencyPdf, exportSubstitutionMapPdf } from "../lib/pdf";
import { DB_EQUIV } from "../lib/realdata";

export default function PatientDetail({ patientId }: { patientId: string }) {
  const { getPatient, plans, go, updatePatient } = useStore();
  const p = getPatient(patientId);
  const [showMeasure, setShowMeasure] = useState(false);
  const [nw, setNw] = useState("");
  const [nwaist, setNwaist] = useState("");
  const [nfat, setNfat] = useState("");

  if (!p) return <p className="text-muted-foreground">Paciente não encontrado.</p>;
  const patient: NonNullable<typeof p> = p;

  const last = patient.measurements[patient.measurements.length - 1];
  const imcVal = imc(last.weight, last.height);
  const cat = imcCategory(imcVal);
  const patientPlans = plans.filter((x) => x.patientId === patient.id);

  const chartData = patient.measurements.map((m) => ({
    date: new Date(m.date + "T12:00:00").toLocaleDateString("pt-BR", { day: "2-digit", month: "short" }),
    peso: m.weight,
    gordura: m.bodyFat,
    cintura: m.waist,
  }));

  function addMeasure() {
    const w = parseFloat(nw.replace(",", "."));
    if (!w) return;
    updatePatient({
      ...patient,
      measurements: [...patient.measurements, {
        date: new Date().toISOString().slice(0, 10),
        weight: w,
        height: last.height,
        waist: nwaist ? parseFloat(nwaist.replace(",", ".")) : undefined,
        bodyFat: nfat ? parseFloat(nfat.replace(",", ".")) : undefined,
      }],
    });
    setShowMeasure(false);
    setNw(""); setNwaist(""); setNfat("");
  }

  return (
    <>
      <button className="mb-6 flex items-center gap-2 text-sm font-medium text-muted-foreground hover:text-foreground" onClick={() => go({ name: "patients" })}>
        <ArrowLeft size={15} /> Pacientes
      </button>

      <div className="mb-8 flex flex-wrap items-start justify-between gap-4">
        <div className="flex items-center gap-4">
          <div className="flex h-16 w-16 items-center justify-center rounded-full bg-forest-100 font-display text-2xl font-semibold text-forest-600">
            {patient.name.split(" ").map((n) => n[0]).slice(0, 2).join("")}
          </div>
          <div>
            <h1 className="font-display text-3xl font-semibold">{patient.name}</h1>
            <p className="text-sm text-muted-foreground">{patient.goal}</p>
            <div className="mt-1.5 flex flex-wrap gap-1.5">
              {patient.tags.map((t) => <span key={t} className="chip text-muted-foreground">{t}</span>)}
            </div>
          </div>
        </div>
        <div className="flex gap-2.5">
          <button className="btn-ghost" onClick={() => setShowMeasure(!showMeasure)}><Plus size={16} /> Nova medida</button>
          <button className="btn-primary" onClick={() => go({ name: "plan-builder", patientId: patient.id })}>
            <CalendarPlus size={16} /> Novo plano
          </button>
        </div>
      </div>

      {showMeasure && (
        <div className="card-warm mb-6 flex flex-wrap items-end gap-4 p-5">
          <div>
            <label className="label-warm">Peso (kg)</label>
            <input autoFocus className="input-warm w-32" value={nw} onChange={(e) => setNw(e.target.value)} placeholder="70,5" />
          </div>
          <div>
            <label className="label-warm">Cintura (cm)</label>
            <input className="input-warm w-32" value={nwaist} onChange={(e) => setNwaist(e.target.value)} placeholder="opcional" />
          </div>
          <div>
            <label className="label-warm">Gordura (%)</label>
            <input className="input-warm w-32" value={nfat} onChange={(e) => setNfat(e.target.value)} placeholder="opcional" />
          </div>
          <button className="btn-primary" onClick={addMeasure}>Registrar</button>
        </div>
      )}

      <div className="grid grid-cols-2 gap-4 sm:grid-cols-4 mb-8">
        {[
          { label: "Peso atual", value: `${last.weight.toFixed(1)} kg` },
          { label: "IMC", value: imcVal.toFixed(1), sub: cat.label, color: cat.color },
          { label: "Gordura corporal", value: last.bodyFat ? `${last.bodyFat}%` : "—" },
          { label: "Cintura", value: last.waist ? `${last.waist} cm` : "—" },
        ].map((c) => (
          <div key={c.label} className="card-warm p-4">
            <p className="eyebrow">{c.label}</p>
            <p className="mt-2 font-display text-2xl font-semibold" style={c.color ? { color: c.color } : {}}>{c.value}</p>
            {c.sub && <p className="text-xs text-muted-foreground">{c.sub}</p>}
          </div>
        ))}
      </div>

      <div className="grid grid-cols-1 gap-6 lg:grid-cols-2">
        <div className="card-warm p-5">
          <p className="eyebrow mb-4">Evolução do peso</p>
          <div className="h-56">
            <ResponsiveContainer width="100%" height="100%">
              <AreaChart data={chartData} margin={{ left: -18, right: 8, top: 4 }}>
                <defs>
                  <linearGradient id="gpeso" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="0%" stopColor="#4a6741" stopOpacity={0.35} />
                    <stop offset="100%" stopColor="#4a6741" stopOpacity={0.02} />
                  </linearGradient>
                </defs>
                <CartesianGrid stroke="#e9e1cd" vertical={false} />
                <XAxis dataKey="date" tick={{ fontSize: 11, fill: "#7a7568" }} axisLine={false} tickLine={false} />
                <YAxis domain={["dataMin - 2", "dataMax + 2"]} tick={{ fontSize: 11, fill: "#7a7568" }} axisLine={false} tickLine={false} />
                <Tooltip contentStyle={{ borderRadius: 12, border: "1px solid #e9e1cd", background: "#fffdf8", fontSize: 13 }} />
                <Area type="monotone" dataKey="peso" stroke="#4a6741" strokeWidth={2.5} fill="url(#gpeso)" />
              </AreaChart>
            </ResponsiveContainer>
          </div>
        </div>

        <div className="card-warm p-5">
          <div className="mb-4 flex items-center justify-between">
            <p className="eyebrow">Planos alimentares</p>
            <button className="btn-ghost !px-3 !py-1.5 text-xs" onClick={() => (DB_EQUIV.length ? exportEquivalencyPdf(p, DB_EQUIV) : exportSubstitutionMapPdf(p, FOODS))}>
              <FileDown size={13} /> Mapa de substituições
            </button>
          </div>
          <div className="space-y-3">
            {patientPlans.map((pl) => {
              const t = planTotals(pl.plan, FOODS);
              return (
                <div key={pl.id} className="rounded-xl border border-border bg-cream-100/60 p-4">
                  <div className="flex items-center justify-between gap-2">
                    <p className="font-semibold">{pl.name}</p>
                    <span className={`chip ${pl.status === "publicado" ? "!border-forest-200 !bg-forest-50 text-forest-600" : "!border-amber-200 !bg-amber-50 text-amber-700"}`}>{pl.status}</span>
                  </div>
                  <p className="mt-1 font-mono text-xs text-muted-foreground">≈ {t.kcal} kcal/dia · P {t.protein}g · C {t.carbs}g · G {t.fat}g</p>
                  <div className="mt-3 flex gap-2">
                    <button className="btn-primary !px-3 !py-1.5 text-xs" onClick={() => go({ name: "plan-builder", planId: pl.id })}>Abrir no construtor</button>
                    <button className="btn-ghost !px-3 !py-1.5 text-xs" onClick={() => exportPlanPdf(pl, p, FOODS)}><FileDown size={13} /> PDF</button>
                    <button className="btn-ghost !px-3 !py-1.5 text-xs" onClick={() => go({ name: "portal", patientId: patient.id })}><Eye size={13} /> Visão do paciente</button>
                  </div>
                </div>
              );
            })}
            {patientPlans.length === 0 && (
              <div className="rounded-xl border border-dashed border-border p-6 text-center text-sm text-muted-foreground">
                Nenhum plano ainda. <button className="font-semibold text-forest-500" onClick={() => go({ name: "plan-builder", patientId: patient.id })}>Criar o primeiro →</button>
              </div>
            )}
          </div>
          {patient.notes && (
            <div className="mt-4 border-t border-border pt-3">
              <p className="eyebrow mb-1.5">Observações</p>
              <p className="text-sm leading-relaxed text-muted-foreground">{patient.notes}</p>
            </div>
          )}
        </div>
      </div>
    </>
  );
}
