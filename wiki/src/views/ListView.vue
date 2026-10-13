<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import type { Category } from '../types.ts'
import { catalog, categories, searchIndex } from '../lib/catalog.ts'
import { search } from '../lib/search.ts'
import EntryCard from '../components/EntryCard.vue'
import WikiIcon from '../components/WikiIcon.vue'

const route = useRoute()
const router = useRouter()
const category = computed(() => categories.find((cat) => cat.id === route.params.category))
const query = computed(() => String(route.query.q ?? ''))
const limit = ref(24)
const tag = computed(() => String(route.query.tag ?? ''))
const tags = computed(() =>
  [
    ...new Set(
      catalog.value?.entries
        .filter((entry) => entry.category === category.value?.id)
        .flatMap((entry) => entry.tags) ?? []
    ),
  ].sort((a, b) => a.localeCompare(b, 'ru'))
)
const matches = computed(() =>
  search(searchIndex, query.value, category.value?.id as Category | undefined).filter(
    (entry) => !tag.value || entry.tags.includes(tag.value)
  )
)
const visible = computed(() => matches.value.slice(0, limit.value))
watch(
  () => route.fullPath,
  () => {
    limit.value = 24
  }
)
/** Сохраняет выбранную разновидность в адресе, чтобы работали закладки и возврат браузером. */
function filter(value: string) {
  router.replace({ query: { ...route.query, tag: value || undefined } })
}
</script>
<template>
  <div class="page">
    <span class="eyebrow">{{ category ? 'СПРАВОЧНИК' : 'ПОИСК ПО ВСЕЙ WIKI' }}</span>
    <h1>{{ category?.title ?? (query ? `Результаты: «${query}»` : 'Все статьи') }}</h1>
    <p class="page-description">
      {{
        category?.description ??
        'Поиск находит названия, описания, требования, ингредиенты и связанные страницы.'
      }}
    </p>
    <div class="list-toolbar">
      <div v-if="category && tags.length" class="filter-tabs" aria-label="Разновидность">
        <button :class="{ selected: !tag }" @click="filter('')">Все</button>
        <button
          v-for="value in tags"
          :key="value"
          :class="{ selected: tag === value }"
          @click="filter(value)"
        >
          {{ value }}
        </button>
      </div>
      <span class="result-count" role="status">Найдено: {{ matches.length }}</span>
    </div>
    <div v-if="visible.length" class="entry-grid">
      <EntryCard
        v-for="entry in visible"
        :key="`${entry.category}/${entry.id}`"
        :entry="entry"
        :show-category="!category"
      />
    </div>
    <div v-else class="empty-state">
      <WikiIcon name="search" :size="36" />
      <h2>Пока ничего не нашлось</h2>
      <p>
        Попробуйте другое название или сократите запрос.
        <br />
        Например: «мята», «горн» или «скелет».
      </p>
      <RouterLink to="/" class="button">Вернуться к разделам</RouterLink>
    </div>
    <button v-if="matches.length > limit" class="button load-more" @click="limit += 24">
      Показать ещё {{ Math.min(24, matches.length - limit) }}
      <span class="muted">· {{ visible.length }} из {{ matches.length }}</span>
    </button>
  </div>
</template>
