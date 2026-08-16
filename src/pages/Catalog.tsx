import { useCallback, useEffect, useMemo, useState } from 'react'
import { Search } from 'lucide-react'
import { PageHeader } from '../components/Shell'
import { CATALOG_PAGE_SIZE, type CatalogDataSource, type CatalogPage } from '../lib/catalogSearch'
import { macroLabels, macroKeys } from '../lib/catalogNutrients'
import { useDebouncedValue } from '../lib/useDebouncedValue'

export interface CatalogPageProps {
  organizationId: string
  dataSource: CatalogDataSource
}

export default function Catalog({ organizationId, dataSource }: CatalogPageProps) {
  const [query, setQuery] = useState('')
  const [page, setPage] = useState(1)
  const [result, setResult] = useState<CatalogPage | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const debouncedQuery = useDebouncedValue(query, 300)

  useEffect(() => { setPage(1) }, [debouncedQuery])

  const load = useCallback(async () => {
    setLoading(true)
    const response = await dataSource.searchFoods({ organizationId, query: debouncedQuery, page })
    if (response.error) {
      setError(response.error.message)
      setResult(null)
    } else {
      setError('')
      setResult(response.data)
    }
    setLoading(false)
  }, [dataSource, organizationId, debouncedQuery, page])

  useEffect(() => { void load() }, [load])

  const range = useMemo(() => {
    if (!result || result.total === 0) return null
    const first = (result.page - 1) * result.pageSize + 1
    const last = first + result.foods.length - 1
    return `${first}–${last} de ${result.total}`
  }, [result])

  return (
    <>
      <PageHeader
        eyebrow="Catálogo nutricional"
        title="Alimentos e preparações"
        description={`Busca no banco em tempo real, ${CATALOG_PAGE_SIZE} resultados por página. Nutriente não informado permanece ausente.`}
      />

      <div className="relative mb-6 max-w-md">
        <Search size={16} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-muted-foreground" aria-hidden="true" />
        <input
          className="input-warm !pl-10"
          aria-label="Buscar no catálogo"
          placeholder="Buscar alimento ou preparação..."
          value={query}
          onChange={(event) => setQuery(event.target.value)}
        />
      </div>

      {error && <p className="mb-6 rounded-xl border border-destructive/30 bg-destructive/10 p-4 text-sm text-destructive" role="alert">{error}</p>}
      <p className="mb-4 text-sm text-muted-foreground" role="status">
        {loading ? 'Buscando no catálogo...' : range ? `Exibindo ${range}` : 'Nenhum alimento encontrado.'}
      </p>

      <div className="overflow-x-auto">
        <table className="w-full min-w-[720px] border-collapse text-sm">
          <caption className="sr-only">Alimentos do catálogo com valores por 100 g</caption>
          <thead>
            <tr className="border-b border-border text-left">
              <th scope="col" className="py-2 pr-4 font-medium">Alimento</th>
              <th scope="col" className="py-2 pr-4 font-medium">Origem</th>
              {macroKeys.map((key) => (
                <th scope="col" key={key} className="py-2 pr-4 text-right font-medium">{macroLabels[key]}</th>
              ))}
            </tr>
          </thead>
          <tbody>
            {(result?.foods ?? []).map((food) => (
              <tr key={food.id} className="border-b border-border/60">
                <td className="py-2.5 pr-4">
                  <span className="font-medium">{food.name}</span>
                  {food.householdMeasureLabel && (
                    <span className="block text-xs text-muted-foreground">
                      {food.householdMeasureLabel}{food.householdMeasureGrams === null ? '' : ` · ${food.householdMeasureGrams} g`}
                    </span>
                  )}
                </td>
                <td className="py-2.5 pr-4 text-muted-foreground">
                  {food.isOwn ? 'Catálogo próprio' : food.sourceName ?? 'Catálogo compartilhado'}
                </td>
                {macroKeys.map((key) => (
                  <td key={key} className="py-2.5 pr-4 text-right font-mono">
                    {food.nutrients[key] === undefined ? <span className="text-muted-foreground" title="Valor não informado na fonte">—</span> : food.nutrients[key]?.toLocaleString('pt-BR')}
                  </td>
                ))}
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {result && result.pageCount > 1 && (
        <nav aria-label="Paginação do catálogo" className="mt-6 flex items-center justify-between gap-4">
          <button type="button" className="btn-ghost" disabled={result.page <= 1 || loading} onClick={() => setPage((current) => Math.max(1, current - 1))}>
            Página anterior
          </button>
          <p className="text-sm text-muted-foreground">Página {result.page} de {result.pageCount}</p>
          <button type="button" className="btn-ghost" disabled={result.page >= result.pageCount || loading} onClick={() => setPage((current) => current + 1)}>
            Próxima página
          </button>
        </nav>
      )}
    </>
  )
}
