<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import type { ProductionGraph, Recipe } from '../lib/production-plan.ts'
import { productionPlan } from '../lib/production-plan.ts'

const props = defineProps<{ graph: ProductionGraph; index: number; batches: number }>()
const choices = ref<Record<string, number>>({})
const stock = ref<Record<string, number>>({})
const result = computed(() =>
  productionPlan(props.graph.recipes, props.index, stock.value, props.batches, choices.value)
)
const root = computed(() => props.graph.recipes[props.index])
const targets = computed(() =>
  [...new Set(result.value.steps.map((step) => step.target))].filter(
    (kind) => kind !== root.value?.output && variants(kind).length > 1
  )
)
const stockKinds = computed(() => [
  ...new Set([
    ...Object.keys(result.value.missing),
    ...Object.keys(stock.value),
    ...result.value.steps.flatMap((step) => Object.keys(props.graph.recipes[step.index]!.inputs)),
  ]),
])
const steps = computed(() => {
  const grouped: {
    recipe: ProductionGraph['recipes'][number]
    index: number
    target: string
    count: number
    batches: number
    key: number
  }[] = []
  for (const step of result.value.steps) {
    const last = grouped.at(-1)
    if (last?.index === step.index && last.target === step.target) {
      last.count += step.count
      last.batches += 1
    } else
      grouped.push({
        recipe: props.graph.recipes[step.index]!,
        index: step.index,
        target: step.target,
        count: step.count,
        batches: 1,
        key: grouped.length,
      })
  }
  return grouped
})
watch(
  () => props.index,
  () => {
    choices.value = {}
    stock.value = {}
  }
)

/** Находит все реальные варианты основного и побочного получения ингредиента. */
function variants(kind: string) {
  return props.graph.recipes
    .map((recipe, index) => ({ recipe, index }))
    .filter(({ recipe }) => recipe.output === kind || Object.hasOwn(recipe.byproducts ?? {}, kind))
}
/** Различает мгновенную общую кухню и уровень личной печи. */
function station(recipe: Recipe) {
  return recipe.public_kitchen
    ? `Общая кухня / личная ур. ${recipe.level}`
    : `${props.graph.stations[recipe.station]} ур. ${recipe.level}`
}
/** Показывает реальные источники из общего экспорта без отдельного списка рецептур. */
function source(kind: string) {
  const labels: Record<string, string> = {
    shop: 'Лавка',
    crop: 'Вырастить',
    gather: 'Собрать',
    mine: 'Кирка',
    tree: 'Деревья',
    animal: 'Уход за животными',
    fish: 'Рыбалка',
    trap: 'Крабовая ловушка',
    enemy: 'Добыча врага',
    wildlife: 'Охота',
    recycle: 'Изучить и разобрать',
    quest: 'Задание',
    apiary: 'Пчеловодство',
  }
  return (
    (props.graph.sources[kind] ?? [])
      .map((entry) =>
        [
          labels[entry.type] ?? 'Источник',
          entry.location && props.graph.locations[entry.location],
          entry.item && props.graph.names[entry.item],
          entry.type === 'recycle' && `×${entry.batch} → ≤×${entry.amount}`,
          entry.seed && props.graph.names[entry.seed],
          entry.quest && props.graph.quests[entry.quest],
          entry.level && `ур. ${entry.level}`,
          entry.interval && `раз в ${entry.interval} дн.`,
          entry.condition && props.graph.conditions[entry.condition],
          entry.seasons?.map((season) => props.graph.seasons[season]).join(', '),
        ]
          .filter(Boolean)
          .join(' · ')
      )
      .join('; ') || 'Источник пока не описан'
  )
}
</script>

<template>
  <section class="info-panel production-plan" aria-label="Производственная цепочка">
    <h2>Производственная цепочка</h2>
    <p>
      Сырьё для {{ Math.min(999, Math.max(1, batches || 1)) }} партий. Топливо и строительство
      станков считаются отдельно. Навыки — базовые.
    </p>
    <p v-if="result.truncated" role="status">Расчёт ограничен: уменьши число партий.</p>
    <p v-else-if="result.warnings.length" role="status">
      Часть цепочки требует внешнего источника:
      {{
        result.warnings
          .map((warning) => graph.names[warning.split(':')[1] ?? ''] ?? 'другого маршрута')
          .join(', ')
      }}.
    </p>
    <details v-if="targets.length">
      <summary>Варианты переработки</summary>
      <label v-for="kind in targets" :key="kind" class="plan-route">
        {{ graph.names[kind] }}
        <select
          :value="choices[kind] ?? variants(kind)[0]?.index"
          @change="choices[kind] = Number(($event.target as HTMLSelectElement).value)"
        >
          <option v-for="variant in variants(kind)" :key="variant.index" :value="variant.index">
            {{ graph.names[variant.recipe.output] }} ×{{ variant.recipe.count }} ←
            {{
              Object.entries(variant.recipe.inputs)
                .map(([kind, count]) => `${graph.names[kind]} ×${count}`)
                .join(', ')
            }}
            · {{ station(variant.recipe) }}
          </option>
        </select>
      </label>
    </details>
    <details>
      <summary>Учесть свои запасы</summary>
      <label v-for="kind in stockKinds" :key="kind" class="plan-route">
        {{ graph.names[kind] }}
        <input
          type="number"
          min="0"
          max="999999"
          :value="stock[kind] ?? 0"
          @input="
            stock[kind] = Math.max(
              0,
              Math.trunc(Number(($event.target as HTMLInputElement).value) || 0)
            )
          "
        />
      </label>
    </details>
    <h3>Недостающее сырьё</h3>
    <p v-if="!Object.keys(result.missing).length">
      Все нужные ингредиенты есть в указанных запасах.
    </p>
    <ul v-else>
      <li v-for="(count, kind) in result.missing" :key="kind">
        <RouterLink :to="`/items/${kind}`">{{ graph.names[kind] }}</RouterLink>
        ×{{ count }}
        <p class="plan-source">{{ source(String(kind)) }}</p>
      </li>
    </ul>
    <details>
      <summary>Шаги производства</summary>
      <ol>
        <li v-for="step in steps" :key="step.key">
          <RouterLink :to="`/craft/${step.recipe.id}`">
            {{ graph.names[step.recipe.output] }}
          </RouterLink>
          ×{{ step.count }} · партий {{ step.batches }} · {{ station(step.recipe) }}
        </li>
      </ol>
    </details>
  </section>
</template>

<style scoped>
.plan-route {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 1rem;
  flex-wrap: wrap;
  margin-block: 0.75rem;
}
.plan-route select {
  max-width: 100%;
  padding: 0.5rem;
}
.plan-route input {
  width: 7rem;
  padding: 0.5rem;
}
.plan-source {
  margin-block: 0.25rem 0.75rem;
  font-size: 0.95rem;
  color: var(--muted, #615542);
}
details {
  margin-block: 1rem;
}
summary {
  cursor: pointer;
  font-weight: 600;
}
</style>
