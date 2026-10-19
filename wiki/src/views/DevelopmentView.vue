<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import {
  planning,
  planningError,
  planningMessage,
  planningLoading,
  planningSaving,
  refinementIdeas,
  loadPlanning,
} from '../lib/planning.ts'
import WikiIcon from '../components/WikiIcon.vue'
import EpicBoard from '../components/EpicBoard.vue'
import IdeaBoard from '../components/IdeaBoard.vue'
import TaskBoard from '../components/TaskBoard.vue'
import DevelopmentSearch from '../components/DevelopmentSearch.vue'
import FirstLocationBoard from '../components/FirstLocationBoard.vue'

const route = useRoute()
const section = computed(() => String(route.params.section ?? 'epics'))
const firstLocationAccepted = computed(() =>
  planning.value?.catalog.tasks.some(
    (task) => task.plan === 'visual' && task.id === 'VMAP-003' && task.status === 'done'
  )
)
const titles: Record<string, string> = {
  'first-location': 'Первая локация · прогресс',
  search: 'Поиск по разработке',
  epics: 'Эпики',
  ideas: 'Идеи',
  refinement: 'На проработку',
  tasks: 'Задачи',
}
const descriptions: Record<string, string> = {
  'first-location': 'Эпики и этапы пути от принятого эталона к целой живописной локации.',
  search: 'Один запрос по идеям, эпикам и всем задачам игры.',
  epics: 'Большие направления игры. Собирайте связанные эпики в удобные группы.',
  ideas: 'Сохраняйте замыслы и выбирайте, какие из них стоит подробно проработать.',
  refinement: 'Одобренные идеи, из которых агент сможет подготовить эпики и задачи.',
  tasks: 'Все карточки разработки: результат, зависимости, приёмка и подтверждения.',
}
let refreshTimer: ReturnType<typeof setInterval> | undefined
onMounted(() => {
  if (!planning.value || section.value === 'first-location') loadPlanning()
  refreshTimer = setInterval(() => {
    if (section.value === 'first-location' && !planningSaving.value) loadPlanning()
  }, 30_000)
})
onBeforeUnmount(() => clearInterval(refreshTimer))
</script>

<template>
  <main class="page development-page">
    <div class="planning-heading">
      <div>
        <span class="eyebrow">РАЗРАБОТКА ДОЛИНЫ</span>
        <h1>{{ titles[section] }}</h1>
        <p>{{ descriptions[section] }}</p>
      </div>
      <button class="button" :disabled="planningLoading || planningSaving" @click="loadPlanning">
        <WikiIcon name="refresh" :size="17" />
        Обновить
      </button>
    </div>
    <p v-if="!firstLocationAccepted && section !== 'first-location'" class="planning-notice">
      <strong>Текущий курс: первая локация целиком до VMAP-003.</strong>
      Новые механики и другие карты — после её приёмки.
      <RouterLink to="/guides/visual-pilot">Эталон и порядок эпиков</RouterLink>
    </p>
    <nav
      v-if="section !== 'first-location'"
      class="planning-flow"
      aria-label="Путь от идеи к реализации"
    >
      <RouterLink to="/development/ideas" :class="{ current: section === 'ideas' }">
        <WikiIcon name="bulb" :size="18" />
        Идеи
        <span>{{ planning?.workspace.ideas.length ?? '—' }}</span>
      </RouterLink>
      <WikiIcon name="chevron" :size="15" />
      <RouterLink to="/development/refinement" :class="{ current: section === 'refinement' }">
        <WikiIcon name="spark" :size="18" />
        На проработку
        <span>{{ refinementIdeas.length }}</span>
      </RouterLink>
      <WikiIcon name="chevron" :size="15" />
      <RouterLink to="/development/epics" :class="{ current: section === 'epics' }">
        <WikiIcon name="layers" :size="18" />
        Эпики
        <span>{{ planning?.catalog.epics.length ?? '—' }}</span>
      </RouterLink>
      <WikiIcon name="chevron" :size="15" />
      <RouterLink to="/development/tasks" :class="{ current: section === 'tasks' }">
        <WikiIcon name="checklist" :size="18" />
        Задачи
        <span>{{ planning?.catalog.tasks.length ?? '—' }}</span>
      </RouterLink>
    </nav>
    <div v-if="planning?.readOnly" class="planning-notice" role="status">
      Открыта сохранённая версия для просмотра. Для сохранения решений запустите значок «Лунная
      долина Wiki» рядом с игрой.
    </div>
    <div v-if="planningError" class="planning-notice error" role="alert">
      {{ planningError }}
      <button class="text-button" @click="loadPlanning">Обновить данные</button>
    </div>
    <p
      v-if="section !== 'first-location'"
      class="planning-save-state"
      role="status"
      aria-live="polite"
    >
      {{
        planningSaving
          ? 'Сохраняем…'
          : planningMessage ||
            (planning?.readOnly
              ? 'Режим просмотра'
              : planning
                ? 'Изменения сохраняются в проекте'
                : '')
      }}
    </p>
    <template v-if="planning">
      <FirstLocationBoard v-if="section === 'first-location'" />
      <DevelopmentSearch v-else-if="section === 'search'" />
      <EpicBoard v-else-if="section === 'epics'" />
      <TaskBoard v-else-if="section === 'tasks'" />
      <IdeaBoard v-else :queue="section === 'refinement'" />
    </template>
    <div v-else class="empty-state">
      <WikiIcon name="layers" :size="45" />
      <h2>{{ planningLoading ? 'Собираем планы…' : 'Планы пока недоступны' }}</h2>
      <p>Здесь будут эпики, идеи и все задачи разработки.</p>
    </div>
  </main>
</template>
