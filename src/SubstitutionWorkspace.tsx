import { useCallback, useEffect, useMemo, useState, type FormEvent } from "react";
import type { Session } from "@supabase/supabase-js";
import { supabase } from "./lib/supabase";
import { rankSubstitutions } from "./lib/substitutionEngine";

type Item = {
  id: string;
  description: string;
  plan_version_id: string;
  plan_title: string;
  patient_name: string;
  nutrients: Record<string, number>;
};
type Food = { id: string; name: string; nutrients: Record<string, number>; tags: string[]; costBand: "low" | "medium" | "high" | null };
type Request = {
  id: string;
  status: string;
  patient_note: string | null;
  professional_note: string | null;
  created_at: string;
  patients: { full_name: string } | null;
  meal_item_substitutions: { description: string } | null;
};

export function SubstitutionWorkspace({
  session,
  organizationId,
}: {
  session: Session;
  organizationId: string;
}) {
  const [items, setItems] = useState<Item[]>([]),
    [foods, setFoods] = useState<Food[]>([]),
    [requests, setRequests] = useState<Request[]>([]),
    [selectedItemId, setSelectedItemId] = useState(""),
    [message, setMessage] = useState(""),
    [busy, setBusy] = useState(false);
  const load = useCallback(async () => {
    const [i, f, r] = await Promise.all([
      supabase
        .from("meal_items")
        .select(
          "id,description,nutrient_snapshot,meals(plan_days(plan_version_id,plan_versions(locked_at,plans(title,patients(full_name)))))",
        )
        .eq("organization_id", organizationId),
      supabase
        .from("foods")
        .select("id,name,cost_band,cultural_tags,preference_tags,availability_tags,food_nutrient_values(amount_per_100g,nutrients(code))")
        .eq("organization_id", organizationId)
        .eq("is_active", true)
        .order("name"),
      supabase
        .from("substitution_requests")
        .select(
          "id,status,patient_note,professional_note,created_at,patients(full_name),meal_item_substitutions(description)",
        )
        .eq("organization_id", organizationId)
        .order("created_at", { ascending: false }),
    ]);
    const error = i.error ?? f.error ?? r.error;
    if (error) return setMessage(error.message);
    const mapped = (i.data ?? []).flatMap((row) => {
      const meal = row.meals as unknown as {
        plan_days: {
          plan_version_id: string;
          plan_versions: {
            locked_at: string | null;
            plans: {
              title: string;
              patients: { full_name: string } | null;
            } | null;
          } | null;
        } | null;
      } | null;
      const day = meal?.plan_days,
        version = day?.plan_versions,
        plan = version?.plans;
      return day && version && !version.locked_at
        ? [
            {
              id: row.id,
              description: row.description,
              plan_version_id: day.plan_version_id,
              plan_title: plan?.title ?? "Plano",
              patient_name: plan?.patients?.full_name ?? "Paciente",
              nutrients: (row.nutrient_snapshot ?? {}) as Record<string, number>,
            },
          ]
        : [];
    });
    setItems(mapped);
    setFoods(((f.data ?? []) as unknown as {id:string;name:string;cost_band:Food['costBand'];cultural_tags:string[]|null;preference_tags:string[]|null;availability_tags:string[]|null;food_nutrient_values:{amount_per_100g:number;nutrients:{code:string}|null}[]}[]).map(food=>({id:food.id,name:food.name,costBand:food.cost_band,tags:[...(food.cultural_tags??[]),...(food.preference_tags??[]),...(food.availability_tags??[])],nutrients:Object.fromEntries((food.food_nutrient_values??[]).map(value=>[value.nutrients?.code==='energy_kcal'?'energyKcal':value.nutrients?.code==='protein_g'?'proteinG':value.nutrients?.code==='carbohydrate_g'?'carbohydrateG':value.nutrients?.code==='fat_g'?'fatG':value.nutrients?.code==='fiber_g'?'fiberG':'',Number(value.amount_per_100g)]).filter(([key])=>key))})));
    setRequests((r.data ?? []) as unknown as Request[]);
    setMessage("");
  }, [organizationId]);
  useEffect(() => {
    void load();
  }, [load]);
  const rankedFoods = useMemo(() => { const item=items.find(value=>value.id===selectedItemId); return item ? rankSubstitutions(foods,{reference:{id:`meal-${item.id}`,name:item.description,nutrients:item.nutrients}}) : foods.map(food=>({...food,score:0,reasons:[]})); }, [foods,items,selectedItemId]);
  async function add(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setBusy(true);
    const d = new FormData(event.currentTarget),
      item = items.find((x) => x.id === d.get("item")),
      food = foods.find((x) => x.id === d.get("food"));
    if (!item || !food) {
      setBusy(false);
      return setMessage("Selecione o item e o alimento substituto.");
    }
    const { error } = await supabase
      .from("meal_item_substitutions")
      .insert({
        organization_id: organizationId,
        plan_version_id: item.plan_version_id,
        meal_item_id: item.id,
        substitute_food_id: food.id,
        description: food.name,
        grams: Number(d.get("grams")),
        unit: "g",
        professional_note: String(d.get("note")) || null,
        created_by: session.user.id,
      });
    setBusy(false);
    setMessage(error?.message ?? "Substituição adicionada ao rascunho.");
    if (!error) {
      event.currentTarget.reset();
      await load();
    }
  }
  async function review(id: string, status: "approved" | "rejected") {
    const note = window.prompt("Resposta ao paciente (opcional):") ?? "";
    const { error } = await supabase.rpc("review_substitution_request", {
      target_request_id: id,
      target_status: status,
      target_note: note || null,
    });
    setMessage(error?.message ?? "Solicitação revisada.");
    if (!error) await load();
  }
  return (
    <div className="care-grid">
      <section className="panel">
        <h2>Adicionar troca autorizada</h2>
        <p className="muted">
          Somente rascunhos desbloqueados. A opção será congelada na publicação.
        </p>
        <form onSubmit={add}>
          <label>
            Item do plano
            <select name="item" required value={selectedItemId} onChange={event=>setSelectedItemId(event.target.value)}>
              <option value="">Selecione</option>
              {items.map((i) => (
                <option key={i.id} value={i.id}>
                  {i.patient_name} · {i.plan_title} · {i.description}
                </option>
              ))}
            </select>
          </label>
          <label>
            Alimento substituto
            <select name="food" required>
              <option value="">Selecione</option>
              {rankedFoods.map((f) => (
                <option key={f.id} value={f.id}>
                  {f.name}{f.reasons.length?` · ${f.reasons.join(', ')}`:''}
                </option>
              ))}
            </select>
          </label>
          {selectedItemId&&rankedFoods[0]&&<small className="muted">Sugestão principal: {rankedFoods[0].name}. {rankedFoods[0].reasons.join(', ') || 'Avalie a equivalência clínica.'}</small>}
          <label>
            Quantidade equivalente (g)
            <input name="grams" type="number" min="0.01" step="0.01" required />
          </label>
          <label>
            Orientação profissional
            <input name="note" maxLength={500} />
          </label>
          <button className="primary" disabled={busy}>
            {busy ? "Salvando..." : "Adicionar opção"}
          </button>
        </form>
        {message && (
          <p className="form-message" role="status">
            {message}
          </p>
        )}
      </section>
      <section className="panel">
        <h2>Pedidos de troca</h2>
        <div className="care-list">
          {requests.length ? (
            requests.map((r) => (
              <article key={r.id}>
                <div>
                  <strong>
                    {r.patients?.full_name ?? "Paciente"} ·{" "}
                    {r.meal_item_substitutions?.description ?? "Opção"}
                  </strong>
                  <time>{new Date(r.created_at).toLocaleString("pt-BR")}</time>
                  <small>{r.patient_note || "Sem justificativa."}</small>
                  {r.professional_note && <p>{r.professional_note}</p>}
                </div>
                <span className={`care-status ${r.status}`}>
                  {r.status === "requested"
                    ? "Em análise"
                    : r.status === "approved"
                      ? "Aprovada"
                      : r.status === "rejected"
                        ? "Recusada"
                        : "Cancelada"}
                </span>
                {r.status === "requested" && (
                  <div className="care-actions">
                    <button onClick={() => void review(r.id, "approved")}>
                      Aprovar
                    </button>
                    <button onClick={() => void review(r.id, "rejected")}>
                      Recusar
                    </button>
                  </div>
                )}
              </article>
            ))
          ) : (
            <p className="muted">Nenhum pedido de troca.</p>
          )}
        </div>
      </section>
    </div>
  );
}
