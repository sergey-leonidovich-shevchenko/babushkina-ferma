<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { useRoute } from 'vue-router'
import type { Category, Entry } from '../types.ts'
import { catalog, categories, entriesByKey, entryPath } from '../lib/catalog.ts'
import { scaleMaterials } from '../lib/search.ts'
import MaterialList from '../components/MaterialList.vue'
import SpriteCanvas from '../components/SpriteCanvas.vue'
import AnimationPlayer from '../components/AnimationPlayer.vue'
import WikiIcon from '../components/WikiIcon.vue'
import ProductionPlan from '../components/ProductionPlan.vue'

const route = useRoute()
const entry = computed(() =>
  entriesByKey.get(`${String(route.params.category)}/${String(route.params.id)}`)
)
const category = computed(() => categories.find((value) => value.id === route.params.category))
const showAnimation = ref(false)
const batches = ref(1)
const copied = ref(false)
const selectedLevel = ref(1)
const ingredients = computed(() =>
  scaleMaterials(
    entry.value?.ingredients ?? [],
    entry.value?.category === 'craft' ? batches.value : 1
  )
)
const yields = computed(() =>
  scaleMaterials(entry.value?.yields ?? [], entry.value?.category === 'craft' ? batches.value : 1)
)
const byproducts = computed(() => scaleMaterials(entry.value?.byproducts ?? [], batches.value))
const level = computed(() =>
  entry.value?.levels?.find((value) => value.level === selectedLevel.value)
)
const portrait = computed(
  () =>
    entry.value?.animation?.clips.find((value) => value.id === `level-${selectedLevel.value}`)
      ?.frames.south?.[0] ?? entry.value?.icon
)
const groups = computed(() => {
  const result = new Map<string, Entry[]>()
  for (const relation of entry.value?.relations ?? []) {
    const related = entriesByKey.get(`${relation.category}/${relation.id}`)
    if (!related) continue
    const list = result.get(relation.group) ?? []
    if (!list.includes(related)) list.push(related)
    result.set(relation.group, list)
  }
  for (const other of catalog.value?.entries ?? []) {
    if (
      other.category !== 'characters' ||
      !other.relations.some(
        (value) => value.category === entry.value?.category && value.id === entry.value?.id
      )
    )
      continue
    const list = result.get('Связанные персонажи') ?? []
    if (!list.includes(other)) list.push(other)
    result.set('Связанные персонажи', list)
  }
  return [...result]
})
watch(
  () => route.fullPath,
  () => {
    showAnimation.value = false
    batches.value = 1
    selectedLevel.value = 1
    copied.value = false
  }
)
/** Копирует обычную ссылку на статью, пригодную для закладки и повторного открытия. */
async function copy() {
  try {
    await navigator.clipboard.writeText(location.href)
    copied.value = true
  } catch {
    copied.value = false
  }
}
</script>
<template>
  <div v-if="entry" class="page article-page" :data-article="`${entry.category}/${entry.id}`">
    <nav class="breadcrumbs" aria-label="Путь статьи">
      <RouterLink to="/">Wiki</RouterLink>
      <WikiIcon name="chevron" :size="13" />
      <RouterLink :to="`/${category?.id}`">{{ category?.title }}</RouterLink>
      <WikiIcon name="chevron" :size="13" />
      <span>{{ entry.title }}</span>
    </nav>
    <div class="article-heading">
      <div>
        <div class="tag-row">
          <span v-for="value in entry.tags" :key="value" class="tag">{{ value }}</span>
        </div>
        <h1>{{ entry.title }}</h1>
        <p class="article-summary">{{ entry.summary }}</p>
      </div>
      <button
        class="icon-button copy-link"
        :aria-label="copied ? 'Ссылка скопирована' : 'Скопировать ссылку'"
        @click="copy"
      >
        <WikiIcon :name="copied ? 'spark' : 'copy'" />
      </button>
    </div>
    <div class="article-layout" :class="{ 'no-portrait': !entry.icon }">
      <main class="article-content">
        <ProductionPlan
          v-if="
            entry.category === 'craft' && entry.recipe_index !== undefined && catalog?.production
          "
          :graph="catalog.production"
          :index="entry.recipe_index"
          :batches="batches"
        />
        <section v-if="entry.facts.length" class="info-panel">
          <h2>Что нужно знать</h2>
          <dl class="facts">
            <template v-for="fact in entry.facts" :key="fact.label">
              <dt>{{ fact.label }}</dt>
              <dd>{{ fact.value }}</dd>
            </template>
          </dl>
        </section>
        <section v-if="entry.ingredients.length && !entry.levels?.length" class="info-panel">
          <div class="section-heading">
            <h2>
              {{
                entry.category === 'missions'
                  ? 'Что принести'
                  : entry.category === 'craft'
                    ? 'Ингредиенты'
                    : 'Материалы для строительства'
              }}
            </h2>
            <label v-if="entry.category === 'craft'" class="batch-control">
              Партий
              <input
                v-model.number="batches"
                type="number"
                min="1"
                max="999"
                aria-label="Количество партий"
              />
            </label>
          </div>
          <MaterialList :materials="ingredients" />
        </section>
        <section v-if="entry.yields.length" class="info-panel">
          <h2>
            {{
              entry.category === 'craft'
                ? 'Получится'
                : entry.category === 'missions'
                  ? 'Награда'
                  : 'Продукты и добыча'
            }}
          </h2>
          <MaterialList :materials="yields" />
          <div v-if="byproducts.length" class="byproducts">
            <h3>Побочный продукт</h3>
            <MaterialList :materials="byproducts" />
          </div>
        </section>
        <section v-if="entry.levels?.length" class="info-panel">
          <h2>Строительство и улучшение</h2>
          <div class="level-tabs">
            <button
              v-for="item in entry.levels"
              :key="item.level"
              :class="{ selected: selectedLevel === item.level }"
              @click="selectedLevel = item.level"
            >
              Уровень {{ item.level }}
            </button>
          </div>
          <p class="muted">
            {{
              selectedLevel === 1
                ? 'Начальные материалы'
                : `Переход с ${selectedLevel - 1}-го на ${selectedLevel}-й уровень`
            }}
            <span v-if="level?.coins">· {{ level.coins }} монет</span>
            <span v-if="level?.seconds">· {{ level.seconds }} сек.</span>
          </p>
          <MaterialList :materials="level?.ingredients ?? []" />
        </section>
        <section v-if="entry.salvage?.length" class="info-panel">
          <h2>После изучения можно разобрать</h2>
          <MaterialList :materials="entry.salvage" />
        </section>
        <section v-if="entry.html" class="guide-content info-panel" v-html="entry.html" />
        <section v-for="section in entry.sections" :key="section.title" class="info-panel">
          <h2>{{ section.title }}</h2>
          <p>{{ section.text }}</p>
        </section>
        <section v-for="[title, related] in groups" :key="title" class="info-panel">
          <h2>
            {{ title }}
            <span class="muted small-count">{{ related.length }}</span>
          </h2>
          <div class="relation-grid">
            <RouterLink
              v-for="other in related"
              :key="`${other.category}/${other.id}`"
              :to="entryPath(other)"
            >
              <SpriteCanvas
                v-if="other.icon"
                :frame="other.icon"
                :tint="other.tint"
                :width="34"
                :height="36"
              />
              <WikiIcon
                v-else
                :name="categories.find((value) => value.id === other.category)?.icon"
                :size="18"
              />
              <span>{{ other.title }}</span>
              <WikiIcon name="chevron" :size="13" />
            </RouterLink>
          </div>
        </section>
      </main>
      <aside v-if="entry.icon" class="portrait-panel">
        <div class="portrait-stage">
          <SpriteCanvas
            :frame="portrait"
            :tint="entry.tint"
            :width="246"
            :height="246"
            :shadow="entry.category === 'characters'"
          />
          <span class="portrait-label">{{ entry.title }}</span>
        </div>
        <button
          v-if="entry.animation"
          class="button primary animation-open"
          @click="showAnimation = true"
        >
          <WikiIcon name="play" :size="16" />
          {{ entry.category === 'characters' ? 'Смотреть анимации' : 'Посмотреть ракурсы' }}
        </button>
        <div v-if="entry.animation" class="portrait-meta">
          {{ entry.category === 'buildings' ? 'Состояний' : 'Действий' }}:
          {{ entry.animation.clips.length }} · игровые кадры
        </div>
        <RouterLink
          v-if="entry.category === 'craft' && entry.output"
          :to="entryPath({ category: 'items' as Category, id: entry.output })"
          class="button"
        >
          Открыть предмет
          <WikiIcon name="arrow" :size="15" />
        </RouterLink>
      </aside>
    </div>
    <AnimationPlayer
      v-if="showAnimation && entry.animation"
      :entry="entry"
      @close="showAnimation = false"
    />
  </div>
  <div v-else class="page empty-state">
    <WikiIcon name="book" :size="40" />
    <h1>Страница не найдена</h1>
    <p>Откройте раздел или воспользуйтесь поиском.</p>
    <RouterLink to="/" class="button primary">В справочник</RouterLink>
  </div>
</template>
