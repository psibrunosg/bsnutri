import { useMemo, useState, type FormEvent } from 'react'
import { Heart, History } from 'lucide-react'
import { describeCatalogServing, deriveServingNutrients, matchesCatalogSearch, type CatalogKind } from '../lib/catalog'
import type { CatalogFood, FoodPreference, FoodSource } from '../lib/useFoodCatalog'
import type { NutrientKey } from '../lib/nutrition'

interface NutritionCatalogProps {
  foods: CatalogFood[]
  sources: FoodSource[]
  keys: NutrientKey[]
  labels: Record<NutrientKey, string>
  busy: boolean
  preferences: FoodPreference[]
  addFood: (event: FormEvent<HTMLFormElement>) => Promise<void>
  saveFoodPreference: (foodId: string, change: Partial<Pick<FoodPreference, 'is_favorite' | 'last_used_at'>>) => Promise<void>
}

export function NutritionCatalog({
  foods,
  sources,
  keys,
  labels,
  busy,
  preferences,
  addFood,
  saveFoodPreference,
}: NutritionCatalogProps) {
  const [kind, setKind] = useState<CatalogKind>('food')
  const [query, setQuery] = useState('')
  const [culturalTag, setCulturalTag] = useState('')
  const [restrictionTag, setRestrictionTag] = useState('')
  const [preferenceTag, setPreferenceTag] = useState('')
  const [availabilityTag, setAvailabilityTag] = useState('')
  const [costBand, setCostBand] = useState('')
  const [onlyFavorites, setOnlyFavorites] = useState(false)
  const [onlyRecent, setOnlyRecent] = useState(false)

  const kindLabels: Record<CatalogKind, string> = { food: 'Alimento', preparation: 'Preparação', combination: 'Combinação' }
  const values = (field: keyof Pick<CatalogFood, 'culturalTags' | 'restrictionTags' | 'preferenceTags' | 'availabilityTags'>) =>
    [...new Set(foods.flatMap(food => food[field]))].sort((a, b) => a.localeCompare(b, 'pt-BR'))

  const filteredFoods = useMemo(
    () =>
      foods.filter(food => {
        const pref = preferences.find(item => item.food_id === food.id)
        return (
          matchesCatalogSearch(food, query) &&
          (!culturalTag || food.culturalTags.includes(culturalTag)) &&
          (!restrictionTag || food.restrictionTags.includes(restrictionTag)) &&
          (!preferenceTag || food.preferenceTags.includes(preferenceTag)) &&
          (!availabilityTag || food.availabilityTags.includes(availabilityTag)) &&
          (!costBand || food.costBand === costBand) &&
          (!onlyFavorites || pref?.is_favorite) &&
          (!onlyRecent || Boolean(pref?.last_used_at))
        )
      }),
    [foods, preferences, query, culturalTag, restrictionTag, preferenceTag, availabilityTag, costBand, onlyFavorites, onlyRecent]
  )

  return (
    <div className="nutrition-grid catalog-workspace">
      <section className="panel catalog-form">
        <span className="eyebrow">Catálogo estruturado</span>
        <h2>Novo item</h2>
        <div className="catalog-kind" role="radiogroup" aria-label="Tipo do item">
          {(Object.keys(kindLabels) as CatalogKind[]).map(value => (
            <button
              type="button"
              role="radio"
              aria-checked={kind === value}
              className={kind === value ? 'active' : ''}
              key={value}
              onClick={() => setKind(value)}
            >
              {kindLabels[value]}
            </button>
          ))}
        </div>
        <form onSubmit={addFood}>
          <input type="hidden" name="catalogKind" value={kind} />
          <label>
            Nome
            <input name="name" required minLength={2} />
          </label>
          <label>
            Estado ou preparo
            <input name="state" placeholder="Ex.: cozido, grelhado" />
          </label>
          <fieldset>
            <legend>Descoberta no catálogo</legend>
            <label>
              Sinônimos e nomes populares
              <input name="searchTerms" placeholder="Ex.: aipim, macaxeira" />
              <small>Separe os termos por vírgula.</small>
            </label>
            <div className="catalog-tags">
              <label>
                Região ou cultura
                <input name="culturalTags" placeholder="Ex.: Nordeste" />
              </label>
              <label>
                Restrição
                <input name="restrictionTags" placeholder="Ex.: sem glúten" />
              </label>
              <label>
                Preferência
                <input name="preferenceTags" placeholder="Ex.: vegetariano" />
              </label>
              <label>
                Disponibilidade
                <input name="availabilityTags" placeholder="Ex.: safra local" />
              </label>
              <label>
                Custo
                <select name="costBand" defaultValue="">
                  <option value="">Não informado</option>
                  <option value="low">Baixo</option>
                  <option value="medium">Médio</option>
                  <option value="high">Alto</option>
                </select>
              </label>
            </div>
          </fieldset>
          <fieldset>
            <legend>Procedência e revisão</legend>
            <label>
              Fonte da base
              <select name="sourceId" defaultValue="">
                <option value="">Declaração própria / sem base vinculada</option>
                {sources.map(source => (
                  <option value={source.id} key={source.id}>
                    {source.name} · {source.dataset_version}
                  </option>
                ))}
              </select>
            </label>
            <label>
              Referência, versão ou observação
              <input name="sourceReference" placeholder="Ex.: tabela consultada em 24/07" />
            </label>
            <div className="yield-inputs">
              <label>
                Data da consulta
                <input name="sourceAccessedOn" type="date" />
              </label>
              <label>
                Confiabilidade declarada
                <select name="sourceReliability" defaultValue="">
                  <option value="">Não informada</option>
                  {[1, 2, 3, 4, 5].map(value => (
                    <option value={value} key={value}>
                      {value}/5
                    </option>
                  ))}
                </select>
              </label>
            </div>
            <label className="check-option">
              <input name="reviewed" type="checkbox" />
              Dados revisados por mim
            </label>
          </fieldset>
          <label>
            Render WebP no repositório
            <input name="renderPath" placeholder="/food-renders/arroz-integral.webp" pattern="/food-renders/.+\\.webp" />
            <small>
              Opcional. Use somente caminho versionado em <code>public/food-renders</code>.
            </small>
          </label>
          {kind === 'food' ? (
            <>
              <p className="muted">Valores conhecidos por 100 g.</p>
              <div className="macro-inputs">
                {keys.map(key => (
                  <label key={key}>
                    {labels[key]} ({key === 'energyKcal' ? 'kcal' : 'g'})<input name={key} type="number" min="0" step="0.01" required />
                  </label>
                ))}
              </div>
            </>
          ) : (
            <>
              <div className="yield-inputs">
                <label>
                  Rendimento total (g)
                  <input name="yieldGrams" type="number" min=".01" step=".01" required />
                </label>
                <label>
                  Número de porções
                  <input name="portionCount" type="number" min=".01" step=".01" required />
                </label>
              </div>
              <div className="yield-inputs">
                <label>
                  Medida caseira
                  <input name="householdMeasureLabel" placeholder="Ex.: 1 concha" />
                </label>
                <label>
                  Peso da medida (g)
                  <input name="householdMeasureGrams" type="number" min=".01" step=".01" placeholder="Ex.: 80" />
                </label>
              </div>
              <small>Porção em gramas é calculada pelo rendimento. Use medida caseira somente com peso registrado.</small>
              <fieldset className="component-picker">
                <legend>Componentes e quantidades</legend>
                {foods.map(food => (
                  <label key={food.id}>
                    <span>
                      <strong>{food.name}</strong>
                      <small>{kindLabels[food.catalogKind]}</small>
                    </span>
                    <input aria-label={`Gramas de ${food.name}`} name={`component-${food.id}`} type="number" min="0" step=".01" placeholder="0 g" />
                  </label>
                ))}
                {!foods.length && <p className="muted">Cadastre ao menos um alimento antes de criar {kindLabels[kind].toLowerCase()}.</p>}
              </fieldset>
            </>
          )}
          <button className="primary" disabled={busy || (kind !== 'food' && !foods.length)}>
            {busy ? 'Salvando...' : `Cadastrar ${kindLabels[kind].toLowerCase()}`}
          </button>
        </form>
      </section>
      <section className="panel">
        <header className="catalog-header">
          <div>
            <span className="eyebrow">Biblioteca da clínica</span>
            <h2>Itens cadastrados</h2>
          </div>
          <strong>{filteredFoods.length}</strong>
        </header>
        <div className="catalog-filters">
          <label>
            Buscar por nome, sinônimo ou preparo
            <input
              aria-label="Buscar no catálogo"
              value={query}
              onChange={event => setQuery(event.target.value)}
              placeholder="Ex.: macaxeira, sem glúten"
            />
          </label>
          <div>
            {(
              [
                ['Região/cultura', culturalTag, setCulturalTag, 'culturalTags'],
                ['Restrição', restrictionTag, setRestrictionTag, 'restrictionTags'],
                ['Preferência', preferenceTag, setPreferenceTag, 'preferenceTags'],
                ['Disponibilidade', availabilityTag, setAvailabilityTag, 'availabilityTags'],
              ] as const
            ).map(([label, value, setValue, field]) => (
              <label key={field}>
                {label}
                <select value={value} onChange={event => setValue(event.target.value)}>
                  <option value="">Todas</option>
                  {values(field).map(option => (
                    <option key={option} value={option}>
                      {option}
                    </option>
                  ))}
                </select>
              </label>
            ))}
            <label>
              Custo
              <select value={costBand} onChange={event => setCostBand(event.target.value)}>
                <option value="">Todos</option>
                <option value="low">Baixo</option>
                <option value="medium">Médio</option>
                <option value="high">Alto</option>
              </select>
            </label>
          </div>
          <span>
            <button
              className={onlyFavorites ? 'active' : ''}
              aria-pressed={onlyFavorites}
              onClick={() => setOnlyFavorites(value => !value)}
            >
              <Heart />
              Favoritos
            </button>
            <button className={onlyRecent ? 'active' : ''} aria-pressed={onlyRecent} onClick={() => setOnlyRecent(value => !value)}>
              <History />
              Recentes
            </button>
          </span>
        </div>
        <div className="food-list">
          {filteredFoods.map(food => {
            const preference = preferences.find(item => item.food_id === food.id)
            const serving = deriveServingNutrients(food.nutrients, food.availableNutrients, food.servingGrams)
            return (
              <article key={food.id} className="food-card">
                {food.renderPath ? (
                  <img className="food-render" src={food.renderPath} alt={`Render de ${food.name}`} />
                ) : (
                  <div className="food-render-placeholder" aria-label={`Sem render para ${food.name}`}>
                    {food.name.slice(0, 1)}
                  </div>
                )}
                <div>
                  <div className="food-title">
                    <span className={`catalog-badge ${food.catalogKind}`}>{kindLabels[food.catalogKind]}</span>
                    <strong>{food.name}</strong>
                    <button
                      className={preference?.is_favorite ? 'favorite active' : 'favorite'}
                      aria-label={`${preference?.is_favorite ? 'Remover' : 'Adicionar'} ${food.name} dos favoritos`}
                      aria-pressed={preference?.is_favorite ?? false}
                      onClick={() => void saveFoodPreference(food.id, { is_favorite: !preference?.is_favorite })}
                    >
                      <Heart />
                    </button>
                  </div>
                  <small>
                    {food.preparationState} · {describeCatalogServing(food)}
                    {food.portionCount ? ` · rende ${food.portionCount} porções` : ''}
                  </small>
                  <div>
                    {food.availableNutrients.includes('energyKcal') ? `${food.nutrients.energyKcal.toLocaleString('pt-BR')} kcal` : 'Energia não informada'} · P {food.availableNutrients.includes('proteinG') ? `${food.nutrients.proteinG.toLocaleString('pt-BR')} g` : '—'} · C {food.availableNutrients.includes('carbohydrateG') ? `${food.nutrients.carbohydrateG.toLocaleString('pt-BR')} g` : '—'} · G {food.availableNutrients.includes('fatG') ? `${food.nutrients.fatG.toLocaleString('pt-BR')} g` : '—'}
                  </div>
                  {food.servingGrams && (
                    <small>
                      Porção: {serving.energyKcal.toLocaleString('pt-BR')} kcal · P {serving.proteinG.toLocaleString('pt-BR')} g · C {serving.carbohydrateG.toLocaleString('pt-BR')} g · G {serving.fatG.toLocaleString('pt-BR')} g
                    </small>
                  )}
                  <small>
                    Fonte: {food.source ? `${food.source.name} · ${food.source.dataset_version}` : food.sourceReference ?? 'não informada'} · revisão: {food.reviewStatus === 'reviewed' ? 'revisado' : 'pendente'}
                  </small>
                  {food.components.length > 0 && <small>{food.components.length} componente(s)</small>}
                </div>
              </article>
            )
          })}
          {!filteredFoods.length && <p className="muted">Nenhum item corresponde aos filtros.</p>}
        </div>
      </section>
    </div>
  )
}
