import { useCallback, useEffect, useState, type FormEvent } from "react";
import type { Session } from "@supabase/supabase-js";
import { AlertTriangle, Check, X } from "lucide-react";
import { supabase } from "./lib/supabase";
import { SubstitutionWorkspace } from "./SubstitutionWorkspace";

type Patient = { id: string; full_name: string };
type Appointment = {
  id: string;
  patient_id: string;
  status: string;
  modality: string;
  starts_at: string;
  ends_at: string;
  patient_note: string | null;
  location_text: string | null;
  external_meeting_url: string | null;
  patients: { full_name: string } | null;
};
type Checkin = {
  id: string;
  occurred_on: string;
  state: string;
  hunger_before: number | null;
  satiety_after: number | null;
  symptoms: string | null;
  note: string | null;
  patients: { full_name: string } | null;
  meals: { label: string } | null;
};
type Alert = {
  id: string;
  kind: string;
  severity: string;
  message: string;
  status: string;
  detected_at: string;
  patient_name?: string | null;
  priority_score?: number;
  patients?: { full_name: string } | null;
};
const statusLabel: Record<string, string> = {
  requested: "Solicitado",
  approved: "Aprovado",
  rejected: "Recusado",
  cancelled: "Cancelado",
  completed: "Concluído",
  no_show: "Não compareceu",
};

export function CareWorkspace({
  session,
  organizationId,
  patients,
}: {
  session: Session;
  organizationId: string;
  patients: Patient[];
}) {
  const [tab, setTab] = useState<"agenda" | "adherence" | "substitutions">(
      "agenda",
    ),
    [appointments, setAppointments] = useState<Appointment[]>([]),
    [checkins, setCheckins] = useState<Checkin[]>([]),
    [alerts, setAlerts] = useState<Alert[]>([]),
    [error, setError] = useState(""),
    [busy, setBusy] = useState(false);
  const load = useCallback(async () => {
    setError("");
    const [a, c, l] = await Promise.all([
      supabase
        .from("appointments")
        .select(
          "id,patient_id,status,modality,starts_at,ends_at,patient_note,location_text,external_meeting_url,patients(full_name)",
        )
        .eq("organization_id", organizationId)
        .order("starts_at"),
      supabase
        .from("meal_checkins")
        .select(
          "id,occurred_on,state,hunger_before,satiety_after,symptoms,note,patients(full_name),meals(label)",
        )
        .eq("organization_id", organizationId)
        .order("occurred_on", { ascending: false })
        .limit(50),
      supabase
        .from("follow_up_queue")
        .select(
          "id,kind,severity,message,status,detected_at,patient_name,priority_score",
        )
        .eq("organization_id", organizationId)
        .order("priority_score", { ascending: false })
        .order("detected_at", { ascending: false })
        .limit(50),
    ]);
    const first = a.error ?? c.error ?? l.error;
    if (first) setError(first.message);
    else {
      setAppointments((a.data ?? []) as unknown as Appointment[]);
      setCheckins((c.data ?? []) as unknown as Checkin[]);
      setAlerts((l.data ?? []) as unknown as Alert[]);
    }
  }, [organizationId]);
  useEffect(() => {
    void load();
  }, [load]);
  async function create(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setBusy(true);
    setError("");
    const d = new FormData(event.currentTarget),
      starts = new Date(String(d.get("starts"))),
      duration = Number(d.get("duration")),
      modality = String(d.get("modality"));
    const payload = {
      organization_id: organizationId,
      patient_id: String(d.get("patient")),
      professional_id: session.user.id,
      requested_by: session.user.id,
      status: "requested",
      modality,
      starts_at: starts.toISOString(),
      ends_at: new Date(starts.getTime() + duration * 60000).toISOString(),
      location_text:
        modality === "in_person"
          ? String(d.get("location")) || "Clínica BS"
          : null,
      patient_note: String(d.get("note")) || null,
    };
    const { error } = await supabase.from("appointments").insert(payload);
    if (error) setError(error.message);
    else {
      event.currentTarget.reset();
      await load();
    }
    setBusy(false);
  }
  async function review(id: string, status: "approved" | "rejected") {
    let meetingUrl: string | null = null;
    const appointment = appointments.find((item) => item.id === id);
    if (status === "approved" && appointment?.modality === "online") {
      const provided = window.prompt("Informe o link da teleconsulta:")?.trim();
      if (!provided) return;
      try {
        const parsed = new URL(provided);
        if (!["https:", "http:"].includes(parsed.protocol)) throw new Error();
      } catch {
        return setError("Informe um link válido, começando com https://.");
      }
      meetingUrl = provided;
    }
    const { error } = await supabase.rpc("review_appointment", {
      target_id: id,
      target_status: status,
      target_staff_note: null,
      target_meeting_url: meetingUrl,
    });
    if (error) setError(error.message);
    else await load();
  }
  async function cancel(id: string) {
    const reason = window.prompt("Motivo do cancelamento:");
    if (!reason) return;
    const { error } = await supabase.rpc("cancel_appointment", {
      target_id: id,
      reason,
    });
    if (error) setError(error.message);
    else await load();
  }
  async function updateAlert(id: string, status: "acknowledged" | "resolved") {
    const { error } = await supabase.rpc("update_alert_status", {
      target_id: id,
      target_status: status,
    });
    if (error) setError(error.message);
    else await load();
  }
  async function createFollowUpAction(
    id: string,
    action: "guidance" | "review_request" | "substitution_request" | "followed_up",
  ) {
    const labels = {
      guidance: "Orientacao curta para o paciente:",
      review_request: "O que deve ser revisado no plano?",
      substitution_request: "Qual troca/substituicao deve ser avaliada?",
      followed_up: "",
    };
    const note =
      action === "followed_up" ? null : window.prompt(labels[action])?.trim();
    if (action !== "followed_up" && !note) return;
    const { error } = await supabase.rpc("create_follow_up_action", {
      target_alert_id: id,
      target_action: action,
      target_note: note,
    });
    if (error) setError(error.message);
    else await load();
  }
  return (
    <section className="care-workspace">
      <div className="section-tabs">
        <button
          className={tab === "agenda" ? "active" : ""}
          onClick={() => setTab("agenda")}
        >
          Agenda
        </button>
        <button
          className={tab === "adherence" ? "active" : ""}
          onClick={() => setTab("adherence")}
        >
          Adesão e alertas
        </button>
        <button
          className={tab === "substitutions" ? "active" : ""}
          onClick={() => setTab("substitutions")}
        >
          Trocas
        </button>
      </div>
      {error && (
        <div className="notice error" role="alert">
          {error}
        </div>
      )}
      {tab === "substitutions" ? (
        <SubstitutionWorkspace session={session} organizationId={organizationId} />
      ) : tab === "agenda" ? (
        <div className="care-grid">
          <section className="panel">
            <h2>Solicitar horário</h2>
            <form onSubmit={create}>
              <label>
                Paciente
                <select name="patient" required>
                  <option value="">Selecione</option>
                  {patients.map((p) => (
                    <option key={p.id} value={p.id}>
                      {p.full_name}
                    </option>
                  ))}
                </select>
              </label>
              <label>
                Início
                <input name="starts" type="datetime-local" required />
              </label>
              <div className="field-row">
                <label>
                  Duração
                  <select name="duration" defaultValue="60">
                    <option value="30">30 min</option>
                    <option value="45">45 min</option>
                    <option value="60">60 min</option>
                    <option value="90">90 min</option>
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
                Local presencial
                <input name="location" placeholder="Clínica BS" />
              </label>
              <label>
                Observação
                <input name="note" maxLength={500} />
              </label>
              <button className="primary" disabled={busy}>
                {busy ? "Salvando..." : "Solicitar horário"}
              </button>
            </form>
          </section>
          <section className="panel">
            <h2>Próximos horários</h2>
            <div className="care-list">
              {appointments.length ? (
                appointments.map((a) => (
                  <article key={a.id}>
                    <div>
                      <strong>{a.patients?.full_name ?? "Paciente"}</strong>
                      <time>
                        {new Date(a.starts_at).toLocaleString("pt-BR")} ·{" "}
                        {new Date(a.ends_at).toLocaleTimeString("pt-BR", {
                          hour: "2-digit",
                          minute: "2-digit",
                        })}
                      </time>
                      <small>
                        {a.modality === "online"
                          ? "Online"
                          : a.modality === "home_visit"
                            ? "Domiciliar"
                            : (a.location_text ?? "Presencial")}
                      </small>
                    </div>
                    <span className={`care-status ${a.status}`}>
                      {statusLabel[a.status] ?? a.status}
                    </span>
                    <div className="care-actions">
                      {a.status === "requested" && (
                        <>
                          <button
                            aria-label="Aprovar"
                            onClick={() => void review(a.id, "approved")}
                          >
                            <Check />
                          </button>
                          <button
                            aria-label="Recusar"
                            onClick={() => void review(a.id, "rejected")}
                          >
                            <X />
                          </button>
                        </>
                      )}
                      {![
                        "cancelled",
                        "rejected",
                        "completed",
                        "no_show",
                      ].includes(a.status) && (
                        <button onClick={() => void cancel(a.id)}>
                          Cancelar
                        </button>
                      )}
                    </div>
                  </article>
                ))
              ) : (
                <p className="muted">Nenhum horário agendado.</p>
              )}
            </div>
          </section>
        </div>
      ) : (
        <div className="care-grid">
          <section className="panel">
            <h2>Alertas clínicos</h2>
            <div className="care-list alerts">
              {alerts.length ? (
                alerts.map((a) => (
                  <article key={a.id}>
                    <AlertTriangle />
                    <div>
                      <strong>
                        {a.patient_name ?? a.patients?.full_name ?? "Paciente"} · {a.message}
                      </strong>
                      <small>
                        {a.severity === "urgent"
                          ? "Urgente"
                          : a.severity === "attention"
                            ? "Atenção"
                            : "Informativo"}{" "}
                        · Prioridade {a.priority_score ?? 0} · {new Date(a.detected_at).toLocaleString("pt-BR")}
                      </small>
                    </div>
                    <span className={`care-status ${a.status}`}>
                      {a.status}
                    </span>
                    <div className="care-actions">
                      {a.status === "open" && (
                        <button
                          onClick={() => void updateAlert(a.id, "acknowledged")}
                        >
                          Reconhecer
                        </button>
                      )}
                      <button
                        onClick={() => void createFollowUpAction(a.id, "guidance")}
                      >
                        Orientar
                      </button>
                      <button
                        onClick={() =>
                          void createFollowUpAction(a.id, "review_request")
                        }
                      >
                        Revisar plano
                      </button>
                      <button
                        onClick={() =>
                          void createFollowUpAction(a.id, "substitution_request")
                        }
                      >
                        Pedir troca
                      </button>
                      {a.status !== "resolved" && (
                        <button
                          onClick={() =>
                            void createFollowUpAction(a.id, "followed_up")
                          }
                        >
                          Acompanhado
                        </button>
                      )}
                    </div>
                  </article>
                ))
              ) : (
                <p className="muted">Nenhum alerta.</p>
              )}
            </div>
          </section>
          <section className="panel">
            <h2>Check-ins recentes</h2>
            <div className="care-list">
              {checkins.length ? (
                checkins.map((c) => (
                  <article key={c.id}>
                    <div>
                      <strong>
                        {c.patients?.full_name ?? "Paciente"} ·{" "}
                        {c.meals?.label ?? "Refeição"}
                      </strong>
                      <time>
                        {new Date(
                          `${c.occurred_on}T12:00:00`,
                        ).toLocaleDateString("pt-BR")}
                      </time>
                      <small>
                        {c.state === "completed"
                          ? "Realizada"
                          : c.state === "adapted"
                            ? "Adaptada"
                            : "Não realizada"}
                        {c.hunger_before !== null
                          ? ` · Fome ${c.hunger_before}/10`
                          : ""}
                        {c.satiety_after !== null
                          ? ` · Saciedade ${c.satiety_after}/10`
                          : ""}
                      </small>
                      {(c.symptoms || c.note) && <p>{c.symptoms || c.note}</p>}
                    </div>
                  </article>
                ))
              ) : (
                <p className="muted">Nenhum check-in.</p>
              )}
            </div>
          </section>
        </div>
      )}
    </section>
  );
}
