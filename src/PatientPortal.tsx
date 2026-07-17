import { useCallback, useEffect, useState, type FormEvent } from "react";
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
  status: string;
  professional_note: string | null;
};
type ShoppingItem = {
  item_key: string;
  description: string;
  total_grams: number;
  occurrences: number;
};
type DriveStatus = { status: "missing" | "connected"; can_upload_photos: boolean };
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
    [drive, setDrive] = useState<DriveStatus>({ status: "missing", can_upload_photos: false }),
    [loading, setLoading] = useState(true),
    [error, setError] = useState("");
  const load = useCallback(async () => {
    setLoading(true);
    setError("");
    const [p, a, r, d] = await Promise.all([
      supabase
        .from("plans")
        .select(
          "id,title,published_at,plan_versions!plans_current_version_tenant_fkey(id,version_no,assistant_state,plan_days(id,label,day_index,meals(id,label,position,suggested_time,meal_items(id,description,grams,nutrient_snapshot,meal_item_substitutions(id,description,grams,unit,professional_note,is_active)))))",
        )
        .eq("patient_id", patient.id)
        .in("status", ["published", "scheduled"])
        .order("published_at", { ascending: false }),
      supabase
        .from("appointments")
        .select("id,starts_at,status,modality")
        .eq("patient_id", patient.id)
        .order("starts_at", { ascending: false }),
      supabase
        .from("substitution_requests")
        .select("id,substitution_id,status,professional_note")
        .eq("patient_id", patient.id)
        .order("created_at", { ascending: false }),
      supabase.rpc("get_patient_drive_status", { target_patient_id: patient.id }),
    ]);
    const first = p.error ?? a.error ?? r.error ?? d.error;
    if (first)
      setError(`Não foi possível carregar seus dados: ${first.message}`);
    else {
      setPlans((p.data ?? []) as unknown as Plan[]);
      setAppointments(a.data ?? []);
      setRequests(r.data ?? []);
      setDrive(((d.data as DriveStatus[] | null)?.[0]) ?? { status: "missing", can_upload_photos: false });
    }
    setLoading(false);
  }, [patient.id]);
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
  return (
    <main className="patient-portal">
      <header>
        <div className="brand">
          <span>BS</span>
          <div>
            <strong>BSNutri</strong>
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
    </main>
  );
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
        {items.map((item) => (
          <label
            className={checked.has(item.item_key) ? "checked" : ""}
            key={item.item_key}
          >
            <input
              type="checkbox"
              checked={checked.has(item.item_key)}
              onChange={() =>
                setChecked((all) => {
                  const next = new Set(all);
                  if (next.has(item.item_key)) next.delete(item.item_key);
                  else next.add(item.item_key);
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
            {checked.has(item.item_key) && <Check />}
          </label>
        ))}
      </div>
    </section>
  );
}

function PlanCard({
  plan,
  patient,
  requests,
  drive,
  reload,
}: {
  plan: Plan;
  patient: PatientAccess;
  requests: SwapRequest[];
  drive: DriveStatus;
  reload: () => Promise<void>;
}) {
  const version = plan.plan_versions;
  const visibility = sanitizePlanVisibility((version?.assistant_state as { visibility?: unknown } | undefined)?.visibility);
  const totals = version ? planSummary(version) : { energyKcal: 0, proteinG: 0, carbohydrateG: 0, fatG: 0 };
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
                    <MealCheckin
                      meal={meal}
                      versionId={version.id}
                      patient={patient}
                      drive={drive}
                    />
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
}: {
  meal: Meal;
  versionId: string;
  patient: PatientAccess;
  drive: DriveStatus;
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
          symptoms: String(d.get("symptoms")) || null,
          note: String(d.get("note")) || null,
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
