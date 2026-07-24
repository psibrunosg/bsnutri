import { useCallback, useEffect, useState, type CSSProperties, type FormEvent } from "react";
import {
  Check,
  ListChecks,
  LogOut,
  RefreshCw,
  ShoppingBasket,
  Utensils,
} from "lucide-react";
import { supabase } from "./lib/supabase";
import { sanitizePlanVisibility, type PlanVisibility } from "./lib/planAssistant";
import { createDriveClient, diaryPhotoFileName } from "./lib/driveClient";
import { printClinicalDocument } from "./lib/clinicalExport";

type PatientAccess = {
  id: string;
  full_name: string;
  anonymous_code: string;
  organization_id: string;
  professional_id: string;
};
type Substitution = {
  id: string;
  description: string;
  grams: number;
  unit: string;
  professional_note: string | null;
};
type Item = {
  id: string;
  description: string;
  grams: number;
  nutrient_snapshot: { food_name?: string; preparation_state?: string; energyKcal?: number; proteinG?: number; carbohydrateG?: number; fatG?: number; nutrients?: { code: string; amount: number }[] } | null;
  meal_item_substitutions: Substitution[];
};
type Meal = {
  id: string;
  label: string;
  position: number;
  suggested_time: string | null;
  meal_items: Item[];
};
type Day = { id: string; label: string; day_index: number; meals: Meal[] };
type Version = { id: string; version_no: number; assistant_state?: unknown; plan_days: Day[] };
type Plan = {
  id: string;
  title: string;
  published_at: string | null;
  plan_versions: Version | null;
};
type Appointment = {
  id: string;
  starts_at: string;
  status: string;
  modality: string;
};
type SwapRequest = {
  id: string;
  substitution_id: string;
  meal_item_id: string;
  plan_version_id: string;
  status: string;
  professional_note: string | null;
};
type ShoppingItem = {
  item_key: string;
  description: string;
  total_grams: number;
  occurrences: number;
};
type IntakeField = { id: string; label: string; field_type: string; required: boolean; position: number };
type IntakeAssignment = {
  id: string;
  status: string;
  form_template_versions: { title: string; form_fields: IntakeField[] } | null;
  form_responses: { values: Record<string, string> }[];
};
type DriveStatus = { status: "missing" | "connected"; can_upload_photos: boolean };
type PatientGoal = { id:string; kind:string; title:string; target_value:number|null; target_unit:string|null };
type WaterLog = { amount_ml:number; occurred_on:string };
type ContentDelivery = { id:string; delivered_at:string; snapshot:{ title?:string; body?:string; content_type?:string } };
type WeeklySummary = { period_days:number; meal_checkins:number; completed_meals:number; water_ml:number; active_goals:number };
type Brand = { public_name:string; primary_color:string; logo_url:string|null };
type OptionalModule = "appointments" | "requests" | "intake" | "goals" | "water" | "branding" | "content" | "drive" | "summary" | "image";
const driveClient = createDriveClient();
type NutritionSummary = { energyKcal: number; proteinG: number; carbohydrateG: number; fatG: number };

function itemAmount(item: Item, code: keyof NutritionSummary, snapshotCode: string) {
  const snapshot = item.nutrient_snapshot;
  return Number(snapshot?.[code] ?? snapshot?.nutrients?.find((n) => n.code === snapshotCode)?.amount ?? 0);
}

function mealSummary(meal: Meal): NutritionSummary {
  return meal.meal_items.reduce((total, item) => ({
    energyKcal: total.energyKcal + itemAmount(item, "energyKcal", "energy_kcal"),
    proteinG: total.proteinG + itemAmount(item, "proteinG", "protein_g"),
    carbohydrateG: total.carbohydrateG + itemAmount(item, "carbohydrateG", "carbohydrate_g"),
    fatG: total.fatG + itemAmount(item, "fatG", "fat_g"),
  }), { energyKcal: 0, proteinG: 0, carbohydrateG: 0, fatG: 0 });
}

function planSummary(version: Version): NutritionSummary {
  return version.plan_days.flatMap((day) => day.meals).reduce((total, meal) => {
    const mealTotal = mealSummary(meal);
    return {
      energyKcal: total.energyKcal + mealTotal.energyKcal,
      proteinG: total.proteinG + mealTotal.proteinG,
      carbohydrateG: total.carbohydrateG + mealTotal.carbohydrateG,
      fatG: total.fatG + mealTotal.fatG,
    };
  }, { energyKcal: 0, proteinG: 0, carbohydrateG: 0, fatG: 0 });
}

function CalculationSummary({ summary, visibility, meal = false }: { summary: NutritionSummary; visibility: PlanVisibility; meal?: boolean }) {
  if (!visibility.showTotalKcal && !visibility.showTotalMacros && !visibility.showMealCalculations) return null;
  const showKcal = meal ? visibility.showMealCalculations : visibility.showTotalKcal;
  const showMacros = meal ? visibility.showMealCalculations : visibility.showTotalMacros;
  if (!showKcal && !showMacros) return null;
  return <p className={meal ? "portal-meal-total" : "portal-plan-total"}>{showKcal&&<span>{Math.round(summary.energyKcal).toLocaleString("pt-BR")} kcal</span>}{showMacros&&<span>P {summary.proteinG.toLocaleString("pt-BR")} g · C {summary.carbohydrateG.toLocaleString("pt-BR")} g · G {summary.fatG.toLocaleString("pt-BR")} g</span>}</p>;
}

export function PatientPortal({ patient }: { patient: PatientAccess }) {
  const [plans, setPlans] = useState<Plan[]>([]),
    [appointments, setAppointments] = useState<Appointment[]>([]),
    [requests, setRequests] = useState<SwapRequest[]>([]),
    [intakeAssignments, setIntakeAssignments] = useState<IntakeAssignment[]>([]),
    [goals, setGoals] = useState<PatientGoal[]>([]),
    [water, setWater] = useState<WaterLog | null>(null),
    [deliveries, setDeliveries] = useState<ContentDelivery[]>([]),
    [weeklySummary, setWeeklySummary] = useState<WeeklySummary | null>(null),
    [brand,setBrand]=useState<Brand|null>(null),
    [drive, setDrive] = useState<DriveStatus>({ status: "missing", can_upload_photos: false }),
    [loading, setLoading] = useState(true),
    [loadError, setLoadError] = useState(""),
    [optionalErrors, setOptionalErrors] = useState<Partial<Record<OptionalModule, string>>>({}),
    [brandImageFailed, setBrandImageFailed] = useState(false),
    [brandImageRetry, setBrandImageRetry] = useState(0),
    [error, setError] = useState("");
  function setOptionalError(module: OptionalModule, message?: string) {
    setOptionalErrors((current) => {
      const next = { ...current };
      if (message) next[module] = message;
      else delete next[module];
      return next;
    });
  }

  const loadPlan = useCallback(async () => {
    setLoading(true);
    setLoadError("");
    const p = await supabase
      .from("plans")
      .select(
        "id,title,published_at,plan_versions!plans_current_version_tenant_fkey(id,version_no,assistant_state,plan_days(id,label,day_index,meals(id,label,position,suggested_time,meal_items(id,description,grams,nutrient_snapshot,meal_item_substitutions(id,description,grams,unit,professional_note,is_active)))))",
      )
      .eq("patient_id", patient.id)
      .in("status", ["published", "scheduled"])
      .order("published_at", { ascending: false });
    if (p.error) setLoadError(`Não foi possível carregar seu plano: ${p.error.message}`);
    else setPlans((p.data ?? []) as unknown as Plan[]);
    setLoading(false);
  }, [patient.id]);

  const loadSupport = useCallback(async () => {
    const [a, r, i, g, w] = await Promise.all([
      supabase
        .from("appointments")
        .select("id,starts_at,status,modality")
        .eq("patient_id", patient.id)
        .order("starts_at", { ascending: false }),
      supabase
        .from("substitution_requests")
        .select("id,substitution_id,meal_item_id,plan_version_id,status,professional_note")
        .eq("patient_id", patient.id)
        .order("created_at", { ascending: false }),
      supabase
        .from("form_assignments")
        .select("id,status,form_template_versions(title,form_fields(id,label,field_type,required,position)),form_responses(values)")
        .eq("patient_id", patient.id)
        .order("assigned_at", { ascending: false }),
      supabase.from("patient_goals").select("id,kind,title,target_value,target_unit").eq("patient_id", patient.id).eq("active", true).order("created_at", { ascending: false }),
      supabase.from("patient_water_logs").select("amount_ml,occurred_on").eq("patient_id", patient.id).eq("occurred_on", new Date().toISOString().slice(0, 10)).order("created_at", { ascending: false }),
    ]);
    if (a.error) setOptionalError("appointments", a.error.message);
    else { setAppointments(a.data ?? []); setOptionalError("appointments"); }
    if (r.error) setOptionalError("requests", r.error.message);
    else { setRequests(r.data ?? []); setOptionalError("requests"); }
    if (i.error) setOptionalError("intake", i.error.message);
    else { setIntakeAssignments((i.data ?? []) as unknown as IntakeAssignment[]); setOptionalError("intake"); }
    if (g.error) setOptionalError("goals", g.error.message);
    else { setGoals((g.data ?? []) as PatientGoal[]); setOptionalError("goals"); }
    if (w.error) setOptionalError("water", w.error.message);
    else { setWater(((w.data ?? []) as WaterLog[])[0] ?? null); setOptionalError("water"); }
  }, [patient.id]);

  const retrySupport = useCallback(async (module: "appointments" | "requests" | "intake" | "goals" | "water") => {
    if (module === "appointments") {
      const result = await supabase.from("appointments").select("id,starts_at,status,modality").eq("patient_id", patient.id).order("starts_at", { ascending: false });
      if (result.error) setOptionalError(module, result.error.message); else { setAppointments(result.data ?? []); setOptionalError(module); }
    } else if (module === "requests") {
      const result = await supabase.from("substitution_requests").select("id,substitution_id,meal_item_id,plan_version_id,status,professional_note").eq("patient_id", patient.id).order("created_at", { ascending: false });
      if (result.error) setOptionalError(module, result.error.message); else { setRequests(result.data ?? []); setOptionalError(module); }
    } else if (module === "intake") {
      const result = await supabase.from("form_assignments").select("id,status,form_template_versions(title,form_fields(id,label,field_type,required,position)),form_responses(values)").eq("patient_id", patient.id).order("assigned_at", { ascending: false });
      if (result.error) setOptionalError(module, result.error.message); else { setIntakeAssignments((result.data ?? []) as unknown as IntakeAssignment[]); setOptionalError(module); }
    } else if (module === "goals") {
      const result = await supabase.from("patient_goals").select("id,kind,title,target_value,target_unit").eq("patient_id", patient.id).eq("active", true).order("created_at", { ascending: false });
      if (result.error) setOptionalError(module, result.error.message); else { setGoals((result.data ?? []) as PatientGoal[]); setOptionalError(module); }
    } else {
      const result = await supabase.from("patient_water_logs").select("amount_ml,occurred_on").eq("patient_id", patient.id).eq("occurred_on", new Date().toISOString().slice(0, 10)).order("created_at", { ascending: false });
      if (result.error) setOptionalError(module, result.error.message); else { setWater(((result.data ?? []) as WaterLog[])[0] ?? null); setOptionalError(module); }
    }
  }, [patient.id]);

  const loadBrand = useCallback(async () => {
    const result = await supabase.from("organization_branding").select("public_name,primary_color,logo_url").eq("organization_id", patient.organization_id).order("updated_at", { ascending: false });
    if (result.error) {
      setBrand(null);
      setOptionalError("branding", result.error.message);
    } else {
      setBrand(((result.data ?? []) as Brand[])[0] ?? null);
      setOptionalError("branding");
    }
  }, [patient.organization_id]);

  const loadDrive = useCallback(async () => {
    const result = await supabase.rpc("get_patient_drive_status", { target_patient_id: patient.id });
    if (result.error) {
      setDrive({ status: "missing", can_upload_photos: false });
      setOptionalError("drive", result.error.message);
    } else {
      setDrive(((result.data as DriveStatus[] | null)?.[0]) ?? { status: "missing", can_upload_photos: false });
      setOptionalError("drive");
    }
  }, [patient.id]);

  const loadDeliveries = useCallback(async () => {
    const result = await supabase.from("patient_content_deliveries").select("id,delivered_at,snapshot").eq("patient_id", patient.id).order("delivered_at", { ascending: false });
    if (result.error) setOptionalError("content", result.error.message);
    else {
      setDeliveries((result.data ?? []) as ContentDelivery[]);
      setOptionalError("content");
    }
  }, [patient.id]);

  const loadWeeklySummary = useCallback(async () => {
    const result = await supabase.rpc("get_patient_weekly_summary", { target_patient_id: patient.id, target_days: 7 });
    if (result.error) setOptionalError("summary", result.error.message);
    else {
      setWeeklySummary((result.data as WeeklySummary | null) ?? null);
      setOptionalError("summary");
    }
  }, [patient.id]);

  const load = useCallback(async () => {
    await Promise.all([loadPlan(), loadSupport(), loadBrand(), loadDrive(), loadDeliveries(), loadWeeklySummary()]);
  }, [loadPlan, loadSupport, loadBrand, loadDrive, loadDeliveries, loadWeeklySummary]);

  useEffect(() => {
    void load();
  }, [load]);
  async function requestAppointment(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError("");
    const d = new FormData(event.currentTarget),
      starts = new Date(String(d.get("starts"))),
      duration = Number(d.get("duration")),
      modality = String(d.get("modality")),
      { data } = await supabase.auth.getSession();
    if (!data.session) return setError("Sua sessão expirou.");
    const { error } = await supabase
      .from("appointments")
      .insert({
        organization_id: patient.organization_id,
        patient_id: patient.id,
        professional_id: patient.professional_id,
        requested_by: data.session.user.id,
        status: "requested",
        modality,
        starts_at: starts.toISOString(),
        ends_at: new Date(starts.getTime() + duration * 60000).toISOString(),
        location_text: modality === "in_person" ? "Clínica BS" : null,
        patient_note: String(d.get("note")) || null,
      });
    if (error) setError(error.message);
    else {
      event.currentTarget.reset();
      await load();
    }
  }
  async function saveIntake(form: HTMLFormElement, assignment: IntakeAssignment, submit: boolean) {
    const { error } = await supabase.rpc("save_form_response", {
      target_assignment_id: assignment.id,
      target_values: Object.fromEntries(new FormData(form).entries()),
      target_submit: submit,
    });
    if (error) setError(error.message);
    else await load();
  }
  async function saveWater(amount:number) {
    if (!Number.isFinite(amount) || amount < 1 || amount > 10000) return setError("Informe entre 1 e 10.000 ml de água.");
    const { data } = await supabase.auth.getSession();
    if (!data.session) return setError("Sua sessão expirou.");
    const { error } = await supabase.from("patient_water_logs").upsert({ organization_id: patient.organization_id, patient_id: patient.id, occurred_on: new Date().toISOString().slice(0, 10), amount_ml: amount, created_by: data.session.user.id }, { onConflict: "patient_id,occurred_on" });
    if (error) setError(error.message); else await load();
  }
  const moduleNotices: { module: OptionalModule; label: string; retry: () => Promise<void> }[] = [
    { module: "appointments", label: "a agenda", retry: () => retrySupport("appointments") },
    { module: "requests", label: "as solicitações de troca", retry: () => retrySupport("requests") },
    { module: "intake", label: "a pré-consulta", retry: () => retrySupport("intake") },
    { module: "goals", label: "as metas", retry: () => retrySupport("goals") },
    { module: "water", label: "o registro de água", retry: () => retrySupport("water") },
    { module: "branding", label: "a marca da clínica", retry: loadBrand },
    { module: "content", label: "as orientações recebidas", retry: loadDeliveries },
    { module: "summary", label: "o resumo semanal", retry: loadWeeklySummary },
    { module: "drive", label: "o envio de fotos", retry: loadDrive },
    { module: "image", label: "a imagem da marca", retry: async () => { setBrandImageFailed(false); setBrandImageRetry((value) => value + 1); } },
  ];
  return (
    <main className="patient-portal" style={{'--clinic-primary':brand?.primary_color ?? '#3e6b5c'} as CSSProperties}>
      <header>
        <div className="brand">
          {brand?.logo_url && !brandImageFailed ? <img key={brandImageRetry} src={brand.logo_url} alt={`Logo ${brand.public_name}`} onLoad={() => setOptionalError("image")} onError={() => { setBrandImageFailed(true); setOptionalError("image", "A imagem não respondeu."); }}/>:<span>BS</span>}
          <div>
            <strong>{brand?.public_name ?? 'BSNutri'}</strong>
            <small>Meu plano alimentar</small>
          </div>
        </div>
        <button className="secondary" onClick={() => supabase.auth.signOut()}>
          <LogOut />
          Sair
        </button>
      </header>
      <section className="portal-hero">
        <small>{patient.anonymous_code}</small>
        <h1>Olá, {patient.full_name.split(" ")[0]}</h1>
        <p>
          Consulte seu plano, registre sua experiência e solicite consultas.
        </p>
      </section>
      {!loading && <TodayHome plans={plans} goals={goals} water={water} weeklySummary={weeklySummary} appointments={appointments} saveWater={saveWater}/>}
      {loadError && <div className="notice error" role="alert"><span>{loadError}</span><button className="secondary" type="button" onClick={() => void loadPlan()}><RefreshCw />Tentar novamente</button></div>}
      {moduleNotices.filter(({ module }) => optionalErrors[module]).map(({ module, label, retry }) => (
        <div className="notice" role="status" key={module}>
          <span>Não foi possível carregar {label}. {optionalErrors[module]}</span>
          <button className="secondary" type="button" onClick={() => void retry()}><RefreshCw />Tentar novamente</button>
        </div>
      ))}
      {error && (
        <div className="notice error" role="alert">
          {error}
        </div>
      )}
      <section className="portal-agenda panel">
        <h2>Solicitar consulta</h2>
        <form onSubmit={requestAppointment}>
          <label>
            Data e horário
            <input name="starts" type="datetime-local" required />
          </label>
          <div className="field-row">
            <label>
              Duração
              <select name="duration" defaultValue="60">
                <option value="30">30 min</option>
                <option value="60">60 min</option>
              </select>
            </label>
            <label>
              Modalidade
              <select name="modality">
                <option value="in_person">Presencial</option>
                <option value="online">Online</option>
                <option value="home_visit">Domiciliar</option>
              </select>
            </label>
          </div>
          <label>
            Observação
            <input name="note" maxLength={500} />
          </label>
          <button className="primary">Solicitar horário</button>
        </form>
        {appointments.map((a) => (
          <p className="portal-appointment" key={a.id}>
            <strong>{new Date(a.starts_at).toLocaleString("pt-BR")}</strong>
            <span>
              {a.status === "requested"
                ? "Aguardando aprovação"
                : a.status === "approved"
                  ? "Confirmada"
                  : a.status === "rejected"
                    ? "Recusada"
                    : a.status === "cancelled"
                      ? "Cancelada"
                      : a.status}
            </span>
          </p>
        ))}
      </section>
      {intakeAssignments.length > 0 && (
        <section className="panel portal-intake">
          <h2>Pre-consulta</h2>
          {intakeAssignments.map((assignment) => {
            const values = assignment.form_responses?.[0]?.values ?? {};
            const fields = assignment.form_template_versions?.form_fields ?? [];
            return (
              <form key={assignment.id} onSubmit={(event) => { event.preventDefault(); void saveIntake(event.currentTarget, assignment, true); }}>
                <strong>{assignment.form_template_versions?.title ?? "Formulario"}</strong>
                <small>{assignment.status === "submitted" ? "Enviado" : assignment.status === "draft" ? "Rascunho salvo" : "Pendente"}</small>
                {fields.sort((a, b) => a.position - b.position).map((field) => (
                  <label key={field.id}>
                    {field.label}{field.required ? " *" : ""}
                    {field.field_type === "long_text" ? (
                      <textarea name={field.id} defaultValue={values[field.id] ?? ""} required={field.required} />
                    ) : field.field_type === "date" ? (
                      <input name={field.id} type="date" defaultValue={values[field.id] ?? ""} required={field.required} />
                    ) : (
                      <input name={field.id} type={field.field_type === "number" || field.field_type === "scale" ? "number" : "text"} min={field.field_type === "scale" ? 0 : undefined} max={field.field_type === "scale" ? 10 : undefined} defaultValue={values[field.id] ?? ""} required={field.required} />
                    )}
                  </label>
                ))}
                {assignment.status !== "submitted" && (
                  <div className="care-actions">
                    <button className="secondary" type="button" onClick={(event) => void saveIntake(event.currentTarget.form!, assignment, false)}>Salvar rascunho</button>
                    <button className="primary">Enviar pre-consulta</button>
                  </div>
                )}
              </form>
            );
          })}
        </section>
      )}
      {plans.length > 0 && <ShoppingList patientId={patient.id} />}{" "}
      {loading ? (
        <div className="portal-empty">Carregando plano...</div>
      ) : plans.length ? (
        <div className="portal-plans">
          {plans.map((plan) => (
            <PlanCard
              key={plan.id}
              plan={plan}
              patient={patient}
              requests={requests}
              drive={drive}
              brandName={brand?.public_name ?? "Clínica BS"}
              reload={load}
            />
          ))}
        </div>
      ) : (
        <div className="portal-empty">
          <Utensils />
          <h2>Nenhum plano publicado</h2>
          <p>Quando o profissional publicar seu plano, ele aparecerá aqui.</p>
          <button className="secondary" onClick={() => void load()}>
            <RefreshCw />
            Atualizar
          </button>
        </div>
      )}
      {deliveries.length > 0 && <section className="panel portal-content"><h2>Orientações recebidas</h2>{deliveries.map(delivery=><article key={delivery.id}><small>{delivery.snapshot.content_type ?? "Orientação"} · {new Date(delivery.delivered_at).toLocaleDateString("pt-BR")}</small><h3>{delivery.snapshot.title ?? "Material da clínica"}</h3><p>{delivery.snapshot.body}</p></article>)}</section>}
    </main>
  );
}

function TodayHome({ plans, goals, water, weeklySummary, appointments, saveWater }: { plans:Plan[]; goals:PatientGoal[]; water:WaterLog|null; weeklySummary:WeeklySummary|null; appointments:Appointment[]; saveWater:(amount:number)=>Promise<void> }) {
  const [amount,setAmount]=useState(water?.amount_ml ?? 0)
  useEffect(()=>setAmount(water?.amount_ml ?? 0),[water?.amount_ml])
  const meals=plans[0]?.plan_versions?.plan_days.flatMap(day=>day.meals).sort((a,b)=>(a.suggested_time??'99:99').localeCompare(b.suggested_time??'99:99')).slice(0,3)??[]
  const appointment=appointments.find(item=>new Date(item.starts_at)>=new Date())
  return <section className="portal-today panel" aria-label="Resumo de hoje"><header><div><small>Hoje</small><h2>Seu próximo passo</h2></div>{appointment&&<time>Próxima consulta: {new Date(appointment.starts_at).toLocaleDateString('pt-BR')}</time>}</header><div className="today-meals"><div><h3>Refeições previstas</h3>{meals.length?meals.map(meal=><p key={meal.id}><strong>{meal.suggested_time?.slice(0,5) ?? 'Livre'}</strong> · {meal.label}</p>):<p className="muted">Seu plano aparecerá aqui quando for publicado.</p>}</div><form onSubmit={event=>{event.preventDefault();void saveWater(amount)}}><h3>Água de hoje</h3><label>ml registrados<input aria-label="Água de hoje em ml" type="number" min="1" max="10000" step="50" value={amount} onChange={event=>setAmount(Number(event.target.value))}/></label><button className="secondary">Salvar água</button></form></div><div className="today-goals"><div><strong>{goals.length}</strong><span>metas ativas</span></div><div><strong>{weeklySummary?.completed_meals ?? 0}</strong><span>refeições registradas na semana</span></div><div><strong>{weeklySummary?.water_ml ?? 0} ml</strong><span>água registrada na semana</span></div></div>{goals.length>0&&<ul className="goal-list">{goals.map(goal=><li key={goal.id}>{goal.title}{goal.target_value!==null&&<> · {goal.target_value} {goal.target_unit}</>}</li>)}</ul>}</section>
}

function ShoppingList({ patientId }: { patientId: string }) {
  const [days, setDays] = useState(7),
    [items, setItems] = useState<ShoppingItem[]>([]),
    [checked, setChecked] = useState<Set<string>>(new Set()),
    [message, setMessage] = useState("");
  const load = useCallback(async () => {
    const { data, error } = await supabase.rpc("get_current_shopping_list", {
      target_patient_id: patientId,
      target_days: days,
    });
    if (error) setMessage(error.message);
    else {
      setItems((data ?? []) as ShoppingItem[]);
      setMessage("");
    }
  }, [patientId, days]);
  useEffect(() => {
    void load();
  }, [load]);
  return (
    <section className="portal-shopping panel">
      <header>
        <div>
          <ShoppingBasket />
          <span>
            <h2>Lista de compras</h2>
            <small>Calculada a partir do plano vigente.</small>
          </span>
        </div>
        <label>
          Período
          <select
            value={days}
            onChange={(e) => setDays(Number(e.target.value))}
          >
            <option value="7">7 dias</option>
            <option value="14">14 dias</option>
            <option value="30">30 dias</option>
          </select>
        </label>
      </header>
      {message && <p className="form-message">{message}</p>}
      <div className="shopping-list">
        {items.map((item, index) => {
          const key = item.item_key || `${item.description}-${index}`;
          return (
            <label className={checked.has(key) ? "checked" : ""} key={key}>
              <input
                type="checkbox"
                checked={checked.has(key)}
                onChange={() =>
                  setChecked((all) => {
                    const next = new Set(all);
                    if (next.has(key)) next.delete(key);
                    else next.add(key);
                    return next;
                  })
                }
              />
              <span>
                <strong>{item.description}</strong>
                <small>
                  {Number(item.total_grams).toLocaleString("pt-BR")} g
                </small>
              </span>
              {checked.has(key) && <Check />}
            </label>
          );
        })}
      </div>
    </section>
  );
}

function PlanCard({
  plan,
  patient,
  requests,
  drive,
  brandName,
  reload,
}: {
  plan: Plan;
  patient: PatientAccess;
  requests: SwapRequest[];
  drive: DriveStatus;
  brandName: string;
  reload: () => Promise<void>;
}) {
  const version = plan.plan_versions;
  const visibility = sanitizePlanVisibility((version?.assistant_state as { visibility?: unknown } | undefined)?.visibility);
  const totals = version ? planSummary(version) : { energyKcal: 0, proteinG: 0, carbohydrateG: 0, fatG: 0 };
  const exportPlan = () => { if (!version) return; const body = version.plan_days.map(day => `${day.label}\n${day.meals.map(meal => `${meal.label}: ${meal.meal_items.map(item => `${item.description} (${item.grams} g)`).join(", ")}`).join("\n")}`).join("\n\n"); printClinicalDocument(`${brandName} · Plano alimentar`, `${patient.full_name} · versão ${version.version_no}`, body); };
  return (
    <article className="portal-plan">
      <header>
        <div>
          <small>Plano vigente</small>
          <h2>{plan.title}</h2>
        </div>
        {plan.published_at && (
          <time>
            Publicado em{" "}
            {new Date(plan.published_at).toLocaleDateString("pt-BR")}
          </time>
        )}
        <button className="secondary" onClick={exportPlan}>Salvar em PDF</button>
      </header>
      <CalculationSummary summary={totals} visibility={visibility}/>
      {version?.plan_days
        ?.sort((a, b) => a.day_index - b.day_index)
        .map((day) => (
          <section className="portal-day" key={day.id}>
            <h3>{day.label}</h3>
            {day.meals
              .sort((a, b) => a.position - b.position)
              .map((meal) => (
                <article className="portal-meal" key={meal.id}>
                  <div>
                    <h4>{meal.label}</h4>
                    {meal.suggested_time && (
                      <time>{meal.suggested_time.slice(0, 5)}</time>
                    )}
                    <CalculationSummary summary={mealSummary(meal)} visibility={visibility} meal/>
                  </div>
                  <div>
                    <ul>
                      {meal.meal_items.map((item) => (
                        <li className="portal-food" key={item.id}>
                          <span>
                            <strong>
                              {item.nutrient_snapshot?.food_name ??
                                item.description}
                            </strong>
                            {item.nutrient_snapshot?.preparation_state && (
                              <small>
                                {item.nutrient_snapshot.preparation_state}
                              </small>
                            )}
                          </span>
                          <b>{Number(item.grams).toLocaleString("pt-BR")} g</b>
                          <Substitutions
                            item={item}
                            versionId={version.id}
                            patient={patient}
                            requests={requests}
                            reload={reload}
                          />
                        </li>
                      ))}
                    </ul>
                    {visibility.showDiary&&<MealCheckin
                      meal={meal}
                      versionId={version.id}
                      patient={patient}
                      drive={drive}
                      approvedRequests={requests.filter(request=>request.status==='approved'&&request.plan_version_id===version.id&&meal.meal_items.some(item=>item.id===request.meal_item_id&&item.meal_item_substitutions.some(option=>option.id===request.substitution_id)))}
                    />}
                  </div>
                </article>
              ))}
          </section>
        ))}
    </article>
  );
}

function Substitutions({
  item,
  versionId,
  patient,
  requests,
  reload,
}: {
  item: Item;
  versionId: string;
  patient: PatientAccess;
  requests: SwapRequest[];
  reload: () => Promise<void>;
}) {
  const [open, setOpen] = useState(false),
    [message, setMessage] = useState("");
  const options = (item.meal_item_substitutions ?? []).filter(Boolean);
  async function request(option: Substitution) {
    const { data } = await supabase.auth.getSession();
    if (!data.session) return setMessage("Sessão expirada.");
    const note =
      window.prompt("Quer explicar o motivo da troca? (opcional)") ?? "";
    const { error } = await supabase
      .from("substitution_requests")
      .insert({
        organization_id: patient.organization_id,
        patient_id: patient.id,
        plan_version_id: versionId,
        meal_item_id: item.id,
        substitution_id: option.id,
        requested_by: data.session.user.id,
        patient_note: note || null,
      });
    setMessage(error?.message ?? "Solicitação enviada para revisão.");
    if (!error) await reload();
  }
  if (!options.length) return null;
  return (
    <div className="substitutions">
      <button className="link" onClick={() => setOpen(!open)}>
        <ListChecks />
        {open ? "Ocultar trocas" : "Ver trocas autorizadas"}
      </button>
      {open && (
        <div>
          {options.map((option) => {
            const latest = requests.find(
              (r) => r.substitution_id === option.id,
            );
            return (
              <article key={option.id}>
                <span>
                  <strong>{option.description}</strong>
                  <small>
                    {Number(option.grams).toLocaleString("pt-BR")} {option.unit}
                    {option.professional_note
                      ? ` · ${option.professional_note}`
                      : ""}
                  </small>
                </span>
                {latest ? (
                  <b className={`care-status ${latest.status}`}>
                    {latest.status === "requested"
                      ? "Em análise"
                      : latest.status === "approved"
                        ? "Aprovada"
                        : latest.status === "rejected"
                          ? "Recusada"
                          : "Cancelada"}
                  </b>
                ) : (
                  <button
                    className="secondary"
                    onClick={() => void request(option)}
                  >
                    Solicitar troca
                  </button>
                )}
              </article>
            );
          })}
        </div>
      )}
      {message && <small role="status">{message}</small>}
    </div>
  );
}

function MealCheckin({
  meal,
  versionId,
  patient,
  drive,
  approvedRequests,
}: {
  meal: Meal;
  versionId: string;
  patient: PatientAccess;
  drive: DriveStatus;
  approvedRequests: SwapRequest[];
}) {
  const [message, setMessage] = useState(""),
    [open, setOpen] = useState(false);
  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setMessage("");
    const form = event.currentTarget,
      d = new FormData(form),
      photoInput = form.elements.namedItem("photo") as HTMLInputElement | null,
      photo = photoInput?.files?.[0],
      { data } = await supabase.auth.getSession();
    if (!data.session) return setMessage("Sessão expirada.");
    const number = (key: string) => {
      const value = String(d.get(key));
      return value === "" ? null : Number(value);
    };
    const { data: checkin, error } = await supabase
      .from("meal_checkins")
      .upsert(
        {
          organization_id: patient.organization_id,
          patient_id: patient.id,
          plan_version_id: versionId,
          meal_id: meal.id,
          occurred_on: String(d.get("date")),
          state: String(d.get("state")),
          hunger_before: number("hunger"),
          satiety_after: number("satiety"),
          mood: number("mood"),
          energy: number("energy"),
          sleep_quality: number("sleep"),
          reaction_suspected: d.get("reaction") === "on",
          symptom_intensity: number("symptomIntensity"),
          help_requested: d.get("help") === "on",
          symptoms: String(d.get("symptoms")) || null,
          note: String(d.get("note")) || null,
          substitution_request_id: String(d.get("approvedSwap")) || null,
          created_by: data.session.user.id,
        },
        { onConflict: "patient_id,meal_id,occurred_on" },
      )
      .select("id")
      .single();
    if (!error && drive.can_upload_photos && photo && photo.size > 0 && checkin?.id) {
      const uploadInput = { organizationId: patient.organization_id, professionalId: patient.professional_id, patientId: patient.id, mealId: meal.id, mealLabel: meal.label, occurredOn: String(d.get("date")), checkinId: checkin.id, file: photo };
      try {
        const uploaded = await driveClient.uploadDiaryPhoto(uploadInput);
        const photoInsert = await supabase.from("meal_checkin_photos").insert({ organization_id: patient.organization_id, patient_id: patient.id, meal_checkin_id: checkin.id, meal_id: meal.id, occurred_on: String(d.get("date")), drive_file_id: uploaded.fileId, drive_web_url: uploaded.webViewLink ?? null, file_name: diaryPhotoFileName(uploadInput), created_by: data.session.user.id });
        if (photoInsert.error) return setMessage(photoInsert.error.message);
      } catch (uploadError) {
        return setMessage(uploadError instanceof Error ? uploadError.message : "Falha ao enviar foto para o Drive");
      }
    }
    setMessage(error?.message ?? "Check-in salvo.");
    if (!error) setOpen(false);
  }
  return (
    <div className="meal-checkin">
      <button className="link" onClick={() => setOpen(!open)}>
        {open ? "Fechar check-in" : "Registrar como foi"}
      </button>
      {open && (
        <form onSubmit={submit}>
          <div className="field-row">
            <label>
              Data
              <input
                name="date"
                type="date"
                defaultValue={new Date().toISOString().slice(0, 10)}
                required
              />
            </label>
            <label>
              Realização
              <select name="state">
                <option value="completed">Realizada</option>
                <option value="adapted">Adaptada</option>
                <option value="skipped">Não realizada</option>
              </select>
            </label>
          </div>
          {approvedRequests.length>0&&<label>Troca aprovada usada<select name="approvedSwap" defaultValue=""><option value="">Não usei troca aprovada</option>{approvedRequests.map(request=>{const option=meal.meal_items.flatMap(item=>item.meal_item_substitutions??[]).find(item=>item.id===request.substitution_id);return <option key={request.id} value={request.id}>{option?`${option.description} · ${Number(option.grams).toLocaleString('pt-BR')} ${option.unit}`:'Troca aprovada'}</option>})}</select></label>}
          <div className="checkin-scales">
            {[
              ["hunger", "Fome antes"],
              ["satiety", "Saciedade depois"],
              ["mood", "Humor"],
              ["energy", "Energia"],
              ["sleep", "Sono"],
            ].map(([name, label]) => (
              <label key={name}>
                {label}
                <input
                  name={name}
                  type="number"
                  min="0"
                  max="10"
                  placeholder="0–10"
                />
              </label>
            ))}
          </div>
          <label className="check-option">
            <input name="reaction" type="checkbox" /> Suspeita de reação ou
            alergia
          </label>
          <label>
            Foto do diario
            <input name="photo" type="file" accept="image/*" disabled={!drive.can_upload_photos} />
            {!drive.can_upload_photos && <small>Fotos indisponiveis ate a clinica conectar o Google Drive.</small>}
          </label>
          <label>
            Sintomas
            <input name="symptoms" maxLength={1000} />
          </label>
          <label>
            Intensidade do sintoma
            <input name="symptomIntensity" type="number" min="0" max="10" placeholder="0-10" />
          </label>
          <label className="check-option">
            <input name="help" type="checkbox" /> Preciso de ajuda
          </label>
          <label>
            Nota
            <input name="note" maxLength={1000} />
          </label>
          <button className="primary">Salvar check-in</button>
        </form>
      )}
      {message && (
        <p className="form-message" role="status">
          {message}
        </p>
      )}
    </div>
  );
}
