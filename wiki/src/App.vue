<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { catalog, categories, loadCatalog, assetUrl } from './lib/catalog.ts'
import WikiIcon from './components/WikiIcon.vue'
import { planning, refinementIdeas, loadPlanning } from './lib/planning.ts'
const route = useRoute()
const router = useRouter()
const query = ref('')
const searchField = ref<HTMLInputElement>()
const drawer = ref(false)
const error = ref(false)
let debounce: ReturnType<typeof setTimeout> | undefined
const development = computed(() => route.path.startsWith('/development'))
const planningSections = computed(() => [
  { id: 'epics', title: 'Эпики', icon: 'layers', count: planning.value?.catalog.epics.length },
  { id: 'ideas', title: 'Идеи', icon: 'bulb', count: planning.value?.workspace.ideas.length },
  { id: 'refinement', title: 'На проработку', icon: 'spark', count: refinementIdeas.value.length },
  { id: 'tasks', title: 'Задачи', icon: 'checklist', count: planning.value?.catalog.tasks.length },
])

/** Открывает готовый справочник, оставляя понятную возможность повтора при ошибке чтения. */
async function load() {
  error.value = false
  try {
    await loadCatalog()
  } catch {
    error.value = true
  }
}
/** Сохраняет полнотекстовый поиск в URL, ограничивая количество переходов при быстром наборе. */
function search() {
  clearTimeout(debounce)
  debounce = setTimeout(() => {
    if (development.value) {
      router.replace({
        path: '/development/search',
        query: { q: query.value.trim() || undefined },
      })
      return
    }
    router.replace(
      query.value.trim() ? { path: '/search', query: { q: query.value.trim() } } : '/search'
    )
  }, 160)
}
/** Открывает результаты немедленно по Enter, не дожидаясь задержки быстрого набора. */
function submit() {
  clearTimeout(debounce)
  if (development.value) {
    router.push({ path: '/development/search', query: { q: query.value.trim() || undefined } })
    return
  }
  router.push({ path: '/search', query: { q: query.value.trim() } })
}
/** Переводит клавиатурный фокус к содержимому без изменения адреса страницы в маршрутизаторе. */
function skip() {
  const target = document.getElementById('wiki-content')
  target?.focus()
  target?.scrollIntoView({ block: 'start' })
}
/** Поддерживает привычный быстрый поиск и закрытие мобильного меню с клавиатуры. */
function shortcut(event: KeyboardEvent) {
  if ((event.ctrlKey || event.metaKey) && event.key.toLowerCase() === 'k') {
    event.preventDefault()
    searchField.value?.focus()
    searchField.value?.select()
  }
  if (event.key === 'Escape' && !(event.target instanceof HTMLDialogElement)) {
    drawer.value = false
    searchField.value?.blur()
  }
}
watch(
  () => route.fullPath,
  () => {
    clearTimeout(debounce)
    query.value = String(route.query.q ?? '')
    drawer.value = false
    document.title = 'Лунная долина · Wiki'
  }
)
onMounted(() => {
  load()
  loadPlanning()
  query.value = String(route.query.q ?? '')
  document.addEventListener('keydown', shortcut)
})
onBeforeUnmount(() => {
  clearTimeout(debounce)
  document.removeEventListener('keydown', shortcut)
})
</script>
<template>
  <a href="#wiki-content" class="skip-link" @click.prevent="skip">Перейти к содержимому</a>
  <button
    v-if="drawer"
    class="mobile-backdrop"
    aria-label="Закрыть навигацию"
    @click="drawer = false"
  />
  <aside class="sidebar" :class="{ expanded: drawer }">
    <RouterLink to="/" class="brand">
      <img :src="assetUrl('wiki-icon.svg')" width="44" height="44" alt="" />
      <span>
        Лунная долина
        <small>WIKI · СПРАВОЧНИК</small>
      </span>
    </RouterLink>
    <nav aria-label="Разделы wiki">
      <RouterLink
        to="/development/first-location"
        class="nav-item location-pin"
        @click="drawer = false"
        :class="{ active: route.params.section === 'first-location' }"
      >
        <WikiIcon name="map" />
        <span>Первая локация · прогресс</span>
      </RouterLink>
      <RouterLink to="/" class="nav-item" :class="{ active: route.path === '/' }">
        <WikiIcon name="home" />
        <span>Главная</span>
      </RouterLink>
      <p class="nav-caption">РАЗРАБОТКА</p>
      <RouterLink
        v-for="section in planningSections"
        :key="section.id"
        :to="`/development/${section.id}`"
        class="nav-item"
        :class="{ active: development && route.params.section === section.id }"
      >
        <WikiIcon :name="section.icon" />
        <span>{{ section.title }}</span>
        <small v-if="section.count !== undefined">{{ section.count }}</small>
      </RouterLink>
      <p class="nav-caption">О ДОЛИНЕ</p>
      <RouterLink
        v-for="category in categories"
        :key="category.id"
        :to="`/${category.id}`"
        class="nav-item"
        :class="{ active: route.params.category === category.id }"
      >
        <WikiIcon :name="category.icon" />
        <span>{{ category.title }}</span>
        <small v-if="catalog">{{ catalog.meta.counts[category.id] }}</small>
      </RouterLink>
    </nav>
    <div class="sidebar-foot">
      <span class="small-orbit">☾</span>
      <p>
        Изучайте мир.
        <br />
        Возвращайтесь за открытиями.
      </p>
      <span v-if="catalog" class="version">Игра {{ catalog.meta.version }}</span>
    </div>
  </aside>
  <div class="workspace">
    <header class="topbar">
      <button
        class="icon-button mobile-menu"
        aria-label="Открыть навигацию"
        :aria-expanded="drawer"
        @click="drawer = !drawer"
      >
        <WikiIcon name="menu" />
      </button>
      <div class="global-search">
        <WikiIcon name="search" :size="19" />
        <input
          ref="searchField"
          v-model="query"
          :placeholder="development ? 'Найти эпик, идею, задачу…' : 'Найти героя, предмет, рецепт…'"
          aria-label="Поиск по wiki"
          type="search"
          autocomplete="off"
          @input="search"
          @keydown.enter="submit"
        />
        <kbd>⌘ / Ctrl K</kbd>
      </div>
      <span class="topbar-label">
        <span class="status-dot" />
        {{ development ? 'Центр разработки' : 'Энциклопедия игры' }}
      </span>
    </header>
    <div id="wiki-content" tabindex="-1">
      <RouterView v-if="catalog" />
      <div v-else class="page loading-state">
        <WikiIcon name="book" :size="48" />
        <h1>{{ error ? 'Не удалось открыть wiki' : 'Открываем справочник…' }}</h1>
        <p>
          {{
            error
              ? 'Запустите значок wiki ещё раз или повторите загрузку.'
              : 'Готовим статьи, связи и игровые иллюстрации.'
          }}
        </p>
        <button v-if="error" class="button primary" @click="load">Повторить загрузку</button>
      </div>
    </div>
    <footer v-if="catalog" class="site-footer">
      <span>Лунная долина · {{ catalog.entries.length }} статей</span>
      <span>Описание и ресурсы из игры {{ catalog.meta.version }}</span>
    </footer>
  </div>
</template>
