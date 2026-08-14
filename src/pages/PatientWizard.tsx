import { useMemo, useState } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { ArrowLeft, ArrowRight, Check, Ruler, User, Target } from "lucide-react";
import { useStore, uid } from "../lib/store";
import type { Patient } from "../lib/types";
import { imc, imcCategory } from "../lib/types";

function Slider({ label, value, min, max, step = 0.1, unit, onChange, hint }: {
  label: string; value: number; min: number; max: number; step?: number; unit: string;
  onChange: (v: number) => void; hint?: string;
}) {
  const fill = ((value - min) / (max - min)) * 100;
  return (
    <div className="rounded-2xl border border-border bg-card p-4">
      <div className="mb-3 flex items-baseline justify-between">
        <label className="text-[13px] font-medium text-foreground/80">{label}</label>
        <p className="font-mono text-lg font-semibold text-forest-600">
          {value.toFixed(step < 1 ? 1 : 0)} <span className="text-xs font-normal text-muted-foreground">{unit}</span>
        </p>
      </div>
      <input
        type="range" min={min} max={max} step={step} value={value}
        onChange={(e) => onChange(Number(e.target.value))}
        className="slider-warm w-full" style={{ ["--fill" as string]: `${fill}%` }}
      />
      {hint && <p className="mt-2 text-[11px] text-muted-foreground">{hint}</p>}
    </div>
  );
}

const STEPS = [
  { id: "dados", label: "Identificação", icon: User },
  { id: "medidas", label: "Antropometria", icon: Ruler },
  { id: "objetivo", label: "Objetivo", icon: Target },
];

export default function PatientWizard() {
  const { addPatient, go } = useStore();
  const [step, setStep] = useState(0);

  const [name, setName] = useState("");
  const [email, setEmail] = useState("");
  const [phone, setPhone] = useState("");
  const [birthDate, setBirthDate] = useState("1995-01-01");
  const [sex, setSex] = useState<"F" | "M" | "Outro">("F");

  const [weight, setWeight] = useState(70);
  const [height, setHeight] = useState(168);
  const [waist, setWaist] = useState(80);
  const [hip, setHip] = useState(96);
  const [arm, setArm] = useState(28);
  const [bodyFat, setBodyFat] = useState(25);

  const [goal, setGoal] = useState("");
  const [notes, setNotes] = useState("");
  const [tagInput, setTagInput] = useState("");
  const [tags, setTags] = useState<string[]>([]);

  const imcVal = useMemo(() => imc(weight, height), [weight, height]);
  const cat = imcCategory(imcVal);
  const rcq = hip > 0 ? waist / hip : 0;

  const imcPos = Math.min(100, Math.max(0, ((imcVal - 14) / (40 - 14)) * 100));

  function finish() {
    const p: Patient = {
      id: uid("p"),
      name: name || "Paciente sem nome",
      email, phone, birthDate, sex,
      goal: goal || "A definir",
      notes, tags,
      createdAt: new Date().toISOString().slice(0, 10),
      measurements: [{ date: new Date().toISOString().slice(0, 10), weight, height, waist, hip, arm, bodyFat }],
    };
    addPatient(p);
    go({ name: "patient-detail", patientId: p.id });
  }

  const canNext = step === 0 ? name.trim().length > 1 : true;

  return (
    <div className="mx-auto max-w-3xl">
      <button className="mb-6 flex items-center gap-2 text-sm font-medium text-muted-foreground hover:text-foreground" onClick={() => go({ name: "patients" })}>
        <ArrowLeft size={15} /> Voltar para pacientes
      </button>

      <p className="eyebrow mb-2">Cadastro facilitado</p>
      <h1 className="font-display text-3xl font-semibold">Novo paciente</h1>

      {/* Stepper */}
      <div className="mt-8 mb-8 flex items-center gap-2">
        {STEPS.map((s, i) => (
          <div key={s.id} className="flex flex-1 items-center gap-2">
            <button
              onClick={() => i < step && setStep(i)}
              className={`flex items-center gap-2.5 rounded-full px-4 py-2 text-sm font-medium transition-all ${
                i === step ? "bg-forest-500 text-cream-50 shadow-warm" : i < step ? "bg-forest-100 text-forest-600" : "bg-cream-200 text-muted-foreground"
              }`}
            >
              {i < step ? <Check size={14} /> : <s.icon size={14} />}
              {s.label}
            </button>
            {i < STEPS.length - 1 && <div className={`h-px flex-1 ${i < step ? "bg-forest-300" : "bg-border"}`} />}
          </div>
        ))}
      </div>

      <AnimatePresence mode="wait">
        <motion.div key={step} initial={{ opacity: 0, x: 24 }} animate={{ opacity: 1, x: 0 }} exit={{ opacity: 0, x: -24 }} transition={{ duration: 0.25 }}>
          {step === 0 && (
            <div className="card-warm space-y-5 p-6">
              <div>
                <label className="label-warm">Nome completo *</label>
                <input autoFocus className="input-warm !py-3 !text-base" value={name} onChange={(e) => setName(e.target.value)} placeholder="Ex.: Mariana Lopes" />
              </div>
              <div className="grid grid-cols-1 gap-5 sm:grid-cols-2">
                <div>
                  <label className="label-warm">E-mail</label>
                  <input className="input-warm" type="email" value={email} onChange={(e) => setEmail(e.target.value)} placeholder="paciente@email.com" />
                </div>
                <div>
                  <label className="label-warm">Telefone / WhatsApp</label>
                  <input className="input-warm" value={phone} onChange={(e) => setPhone(e.target.value)} placeholder="(53) 9 9999-9999" />
                </div>
                <div>
                  <label className="label-warm">Data de nascimento</label>
                  <input className="input-warm" type="date" value={birthDate} onChange={(e) => setBirthDate(e.target.value)} />
                </div>
                <div>
                  <label className="label-warm">Sexo</label>
                  <div className="flex gap-2">
                    {(["F", "M", "Outro"] as const).map((s) => (
                      <button
                        key={s} type="button" onClick={() => setSex(s)}
                        className={`flex-1 rounded-xl border px-3 py-2.5 text-sm font-medium transition-all ${
                          sex === s ? "border-forest-400 bg-forest-50 text-forest-600 shadow-warm" : "border-border bg-card text-muted-foreground hover:border-forest-200"
                        }`}
                      >
                        {s === "F" ? "Feminino" : s === "M" ? "Masculino" : "Outro"}
                      </button>
                    ))}
                  </div>
                </div>
              </div>
            </div>
          )}

          {step === 1 && (
            <div className="grid grid-cols-1 gap-5 lg:grid-cols-5">
              <div className="space-y-4 lg:col-span-3">
                <Slider label="Peso corporal" value={weight} min={35} max={180} unit="kg" onChange={setWeight} />
                <Slider label="Estatura" value={height} min={130} max={210} step={1} unit="cm" onChange={setHeight} />
                <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
                  <Slider label="Circ. cintura" value={waist} min={50} max={160} step={0.5} unit="cm" onChange={setWaist} />
                  <Slider label="Circ. quadril" value={hip} min={60} max={170} step={0.5} unit="cm" onChange={setHip} />
                  <Slider label="Circ. braço" value={arm} min={15} max={55} step={0.5} unit="cm" onChange={setArm} />
                  <Slider label="Gordura corporal" value={bodyFat} min={4} max={55} step={0.5} unit="%" onChange={setBodyFat} hint="Bioimpedância ou dobras cutâneas" />
                </div>
              </div>

              {/* Live panel */}
              <div className="lg:col-span-2">
                <div className="card-warm sticky top-6 space-y-5 p-5">
                  <p className="eyebrow">Leitura ao vivo</p>
                  <div>
                    <div className="flex items-baseline justify-between">
                      <p className="text-sm font-medium">IMC</p>
                      <p className="font-display text-3xl font-semibold" style={{ color: cat.color }}>{imcVal.toFixed(1)}</p>
                    </div>
                    <div className="relative mt-2 h-2.5 rounded-full" style={{ background: "linear-gradient(90deg,#c98f2f 0%,#4a6741 25%,#4a6741 40%,#c98f2f 58%,#a03a2a 100%)" }}>
                      <div className="absolute -top-1 h-4.5 w-1 rounded-full bg-forest-900 shadow" style={{ left: `calc(${imcPos}% - 2px)`, height: 18, top: -4 }} />
                    </div>
                    <p className="mt-2 text-sm font-medium" style={{ color: cat.color }}>{cat.label}</p>
                  </div>
                  <div className="grid grid-cols-2 gap-3 border-t border-border pt-4">
                    <div>
                      <p className="font-mono text-lg font-semibold text-forest-600">{rcq.toFixed(2)}</p>
                      <p className="text-[11px] text-muted-foreground">Relação cintura-quadril</p>
                    </div>
                    <div>
                      <p className="font-mono text-lg font-semibold text-forest-600">
                        {Math.round(sex === "M" ? 66 + 13.7 * weight + 5 * height - 6.8 * 30 : 655 + 9.6 * weight + 1.8 * height - 4.7 * 30)} kcal
                      </p>
                      <p className="text-[11px] text-muted-foreground">TMB estimada (HB)</p>
                    </div>
                  </div>
                  <p className="text-[11px] leading-relaxed text-muted-foreground">
                    Estes indicadores se atualizam enquanto você ajusta — ideal para mostrar ao paciente durante a consulta.
                  </p>
                </div>
              </div>
            </div>
          )}

          {step === 2 && (
            <div className="card-warm space-y-5 p-6">
              <div>
                <label className="label-warm">Objetivo do acompanhamento</label>
                <div className="mb-3 grid grid-cols-2 gap-2 sm:grid-cols-4">
                  {["Perda de peso", "Ganho de massa", "Manutenção", "Performance"].map((g) => (
                    <button
                      key={g} type="button" onClick={() => setGoal(g)}
                      className={`rounded-xl border px-3 py-2.5 text-sm font-medium transition-all ${
                        goal === g ? "border-amber-400 bg-amber-50 text-amber-700 shadow-warm" : "border-border bg-card text-muted-foreground hover:border-amber-200"
                      }`}
                    >
                      {g}
                    </button>
                  ))}
                </div>
                <input className="input-warm" value={goal} onChange={(e) => setGoal(e.target.value)} placeholder="Ou descreva livremente..." />
              </div>
              <div>
                <label className="label-warm">Tags do paciente</label>
                <div className="flex gap-2">
                  <input
                    className="input-warm" value={tagInput} onChange={(e) => setTagInput(e.target.value)}
                    placeholder="Ex.: low carb, vegetariano, corrida"
                    onKeyDown={(e) => {
                      if (e.key === "Enter" && tagInput.trim()) {
                        e.preventDefault();
                        setTags((t) => [...new Set([...t, tagInput.trim().toLowerCase()])]);
                        setTagInput("");
                      }
                    }}
                  />
                </div>
                <div className="mt-2 flex flex-wrap gap-1.5">
                  {tags.map((t) => (
                    <button key={t} className="chip text-forest-600 hover:border-destructive/40 hover:text-destructive" onClick={() => setTags(tags.filter((x) => x !== t))}>
                      {t} ×
                    </button>
                  ))}
                </div>
              </div>
              <div>
                <label className="label-warm">Observações clínicas</label>
                <textarea className="input-warm min-h-[100px] resize-y" value={notes} onChange={(e) => setNotes(e.target.value)} placeholder="Rotina, restrições, preferências, histórico..." />
              </div>
            </div>
          )}
        </motion.div>
      </AnimatePresence>

      <div className="mt-8 flex justify-between">
        <button className="btn-ghost" disabled={step === 0} onClick={() => setStep((s) => s - 1)}>
          <ArrowLeft size={16} /> Anterior
        </button>
        {step < 2 ? (
          <button className="btn-primary" disabled={!canNext} onClick={() => setStep((s) => s + 1)}>
            Continuar <ArrowRight size={16} />
          </button>
        ) : (
          <button className="btn-amber !px-6" onClick={finish}>
            <Check size={16} /> Concluir cadastro
          </button>
        )}
      </div>
    </div>
  );
}
