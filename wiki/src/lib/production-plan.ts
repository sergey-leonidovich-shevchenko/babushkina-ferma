export interface Recipe {
  id: string
  output: string
  count: number
  inputs: Record<string, number>
  byproducts?: Record<string, number>
  station: string
  level: number
  no_bonus?: boolean
  public_kitchen?: boolean
}
export interface Source {
  type: string
  location?: string
  item?: string
  seed?: string
  quest?: string
  level?: number
  amount?: number
  buy?: number
  seasons?: string[]
  condition?: string
  interval?: number
  batch?: number
}
export interface ProductionGraph {
  recipes: Recipe[]
  names: Record<string, string>
  sources: Record<string, Source[]>
  locations: Record<string, string>
  stations: Record<string, string>
  quests: Record<string, string>
  seasons: Record<string, string>
  conditions: Record<string, string>
}
export interface PlanOptions {
  costs?: Record<string, Record<string, number>>
  counter?: number
  master?: boolean
}
export interface PlanResult {
  missing: Record<string, number>
  remaining: Record<string, number>
  steps: { index: number; id: string; count: number; target: string }[]
  warnings: string[]
  truncated: boolean
  output_count: number
}

/** Планирует виртуальные партии по общему каталогу; контракт сверяется с результатами Godot. */
export function productionPlan(
  recipes: Recipe[],
  index: number,
  stock: Record<string, number> = {},
  batches = 1,
  choices: Record<string, number> = {},
  options: PlanOptions = {}
): PlanResult {
  const result: PlanResult = {
    missing: {},
    remaining: {},
    steps: [],
    warnings: [],
    truncated: false,
    output_count: 0,
  }
  if (!recipes[index]) return { ...result, truncated: true, warnings: ['recipe'] }
  const available = { ...stock }
  let counter = options.counter ?? 0
  let operations = 0
  const outputs = new Map<string, number[]>()
  recipes.forEach((recipe, recipeIndex) => {
    for (const kind of [recipe.output, ...Object.keys(recipe.byproducts ?? {})]) {
      const indices = outputs.get(kind) ?? []
      if (!indices.includes(recipeIndex)) indices.push(recipeIndex)
      outputs.set(kind, indices)
    }
  })

  /** Сохраняет внешнюю потребность и причину остановки рекурсивного пути. */
  function missing(kind: string, amount: number, warning = '') {
    result.missing[kind] = (result.missing[kind] ?? 0) + amount
    if (warning && !result.warnings.includes(warning)) result.warnings.push(warning)
  }

  /** Использует остатки и учитывает побочные продукты как альтернативные источники. */
  function need(kind: string, amount: number, path: string[], depth: number) {
    let taken = Math.min(Math.max(0, available[kind] ?? 0), amount)
    available[kind] = (available[kind] ?? 0) - taken
    amount -= taken
    if (amount <= 0) return
    if (path.includes(kind) || depth >= 12) {
      missing(kind, amount, `${path.includes(kind) ? 'cycle' : 'depth'}:${kind}`)
      return
    }
    const candidates = outputs.get(kind) ?? []
    if (!candidates.length) {
      missing(kind, amount)
      return
    }
    const chosen = candidates.includes(choices[kind] ?? -1) ? choices[kind]! : candidates[0]!
    while (amount > 0) {
      if (batch(chosen, [...path, kind], depth + 1) < 0) return
      taken = Math.min(Math.max(0, available[kind] ?? 0), amount)
      if (taken <= 0) {
        result.truncated = true
        return
      }
      available[kind] = (available[kind] ?? 0) - taken
      amount -= taken
    }
  }

  /** Применяет полный выход, порядок пятого крафта и точные входы текущих навыков. */
  function batch(recipeIndex: number, path: string[], depth: number): number {
    operations += 1
    if (operations > 4096) {
      result.truncated = true
      return -1
    }
    const recipe = recipes[recipeIndex]!
    if (recipe.count <= 0) {
      result.truncated = true
      return -1
    }
    const costs = options.costs?.[String(recipeIndex)] ?? recipe.inputs
    for (const kind of Object.keys(recipe.inputs).sort()) {
      need(kind, Math.max(1, Math.trunc(costs[kind] ?? recipe.inputs[kind]!)), path, depth)
      if (result.truncated) return -1
    }
    let count = recipe.count
    if ((recipe.station ?? 'workbench') === 'workbench') {
      counter += 1
      if (options.master && counter % 5 === 0 && !recipe.no_bonus) count *= 2
    }
    available[recipe.output] = (available[recipe.output] ?? 0) + count
    for (const [kind, amount] of Object.entries(recipe.byproducts ?? {})) {
      available[kind] = (available[kind] ?? 0) + amount
    }
    result.steps.push({
      index: recipeIndex,
      id: recipe.id ?? `legacy-${recipeIndex}`,
      count,
      target: path.at(-1)!,
    })
    return count
  }

  const recipe = recipes[index]!
  for (
    let current = 0;
    current < Math.max(1, Math.min(999, Math.trunc(batches) || 1));
    current += 1
  ) {
    const count = batch(index, [recipe.output], 0)
    if (count < 0) break
    result.output_count += count
    available[recipe.output] = (available[recipe.output] ?? 0) - count
  }
  result.remaining = Object.fromEntries(Object.entries(available).filter(([, count]) => count > 0))
  return result
}
