<script setup lang="ts">
import { computed, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import {
  planning,
  planningSaving,
  changePlanning,
  developmentPath,
  matchesQuery,
  taskLabels,
} from '../lib/planning.ts'
import WikiIcon from './WikiIcon.vue'
import TaskBoard from './TaskBoard.vue'

const route = useRoute(),
  router = useRouter()
const groupTitle = ref('')
const group = computed(() => String(route.query.group ?? ''))
const query = computed(() => String(route.query.q ?? ''))
const selected = computed(() =>
  planning.value?.catalog.epics.find((epic) => epic.key === route.params.id)
)
const epics = computed(() =>
  planning.value!.catalog.epics.filter(
    (epic) =>
      (!group.value || epicGroup(epic.key, epic.group) === group.value) &&
      matchesQuery(query.value, epic.id, epic.title, epic.goal)
  )
)
const grouped = computed(() =>
  planning
    .value!.workspace.groups.map((item) => ({
      ...item,
      epics: epics.value.filter((epic) => epicGroup(epic.key, epic.group) === item.id),
    }))
    .filter((item) => item.epics.length)
)
const editable = computed(() => !planning.value?.readOnly && !planningSaving.value)
const totals = computed(() => {
  const result: Record<string, { total: number; done: number; active: number }> = {}
  for (const task of planning.value!.catalog.tasks) {
    const row = (result[task.epic] ??= { total: 0, done: 0, active: 0 })
    row.total++
    if (task.status === 'done') row.done++
    if (task.status === 'in_progress') row.active++
  }
  return result
})
/** Читает пользовательскую группировку поверх исходного назначения плана. */
function epicGroup(key: string, fallback: string) {
  return planning.value!.workspace.epicGroups[key] ?? fallback
}
/** Сохраняет выбранную группу и возвращает прежнее значение при отказе. */
async function move(event: Event, key: string, original: string) {
  const select = event.target as HTMLSelectElement
  if (!(await changePlanning({ type: 'move-epic', epic: key, group: select.value })))
    select.value = original
}
/** Создаёт именованную группу без переноса или дублирования исходных задач. */
async function createGroup(rename = false) {
  if (
    await changePlanning({
      type: rename ? 'rename-group' : 'create-group',
      id: group.value,
      title: groupTitle.value,
    })
  )
    groupTitle.value = ''
}
</script>

<template>
  <template v-if="route.params.id">
    <RouterLink class="planning-back" to="/development/epics">
      <WikiIcon name="back" :size="17" />
      Все эпики
    </RouterLink>
    <template v-if="selected">
      <div class="planning-panel epic-detail">
        <span class="planning-code">{{ selected.id }}</span>
        <h2>{{ selected.title }}</h2>
        <p v-if="selected.goal">{{ selected.goal }}</p>
        <span class="muted">
          {{ planning!.catalog.plans.find((plan) => plan.id === selected?.plan)?.title }}
        </span>
      </div>
      <TaskBoard :epic-key="selected.key" />
    </template>
    <div v-else class="empty-state">
      <h2>Эпик не найден</h2>
      <p>Обновите список или вернитесь ко всем эпикам.</p>
    </div>
  </template>
  <template v-else>
    <div class="planning-toolbar">
      <label class="planning-search">
        <WikiIcon name="search" :size="18" />
        <input
          :value="query"
          placeholder="Название или ID эпика"
          aria-label="Поиск эпиков"
          @input="
            router.replace({
              query: { ...route.query, q: ($event.target as HTMLInputElement).value || undefined },
            })
          "
        />
      </label>
      <label class="planning-select">
        Группа
        <select
          :value="group"
          @change="
            router.replace({
              query: {
                ...route.query,
                group: ($event.target as HTMLSelectElement).value || undefined,
              },
            })
          "
        >
          <option value="">Все группы</option>
          <option v-for="item in planning!.workspace.groups" :key="item.id" :value="item.id">
            {{ item.title }}
          </option>
        </select>
      </label>
    </div>
    <details class="group-editor">
      <summary>
        <WikiIcon name="layers" :size="16" />
        Управление группами
      </summary>
      <form @submit.prevent="createGroup()">
        <label>
          Название группы
          <input
            v-model="groupTitle"
            maxlength="100"
            placeholder="Например, первая неделя на ферме"
            required
          />
        </label>
        <button class="button" :disabled="!editable || !groupTitle.trim()">Создать группу</button>
        <button
          type="button"
          class="button"
          :disabled="!editable || !group || !groupTitle.trim()"
          @click="createGroup(true)"
        >
          Переименовать выбранную
        </button>
      </form>
      <p>
        Выберите группу в фильтре, чтобы изменить её название. Эпик можно перенести через меню на
        его карточке.
      </p>
    </details>
    <section v-for="item in grouped" :key="item.id" class="epic-group">
      <div class="section-heading">
        <h2>{{ item.title }}</h2>
        <span class="muted">Эпиков: {{ item.epics.length }}</span>
      </div>
      <div class="epic-grid">
        <article v-for="epic in item.epics" :key="epic.key" class="epic-card">
          <div class="epic-card-top">
            <span class="planning-code">{{ epic.id }}</span>
            <span v-if="totals[epic.key]?.active" class="planning-status in_progress">
              {{ taskLabels.in_progress }}
            </span>
          </div>
          <RouterLink :to="developmentPath('epics', epic.key)">
            <h3>{{ epic.title }}</h3>
          </RouterLink>
          <p>{{ planning!.catalog.plans.find((plan) => plan.id === epic.plan)?.title }}</p>
          <div class="epic-progress">
            <span>
              {{ totals[epic.key]?.done ?? 0 }} из {{ totals[epic.key]?.total ?? 0 }} завершено
            </span>
            <span>
              {{
                totals[epic.key]?.total
                  ? Math.round((totals[epic.key]!.done / totals[epic.key]!.total) * 100)
                  : 0
              }}%
            </span>
          </div>
          <progress
            :value="totals[epic.key]?.done ?? 0"
            :max="totals[epic.key]?.total || 1"
            :aria-label="`Выполнение ${epic.id}`"
          />
          <div class="epic-card-foot">
            <RouterLink :to="developmentPath('epics', epic.key)">
              Открыть задачи
              <WikiIcon name="arrow" :size="15" />
            </RouterLink>
            <select
              :value="item.id"
              :aria-label="`Группа эпика ${epic.id}`"
              :disabled="!editable"
              @change="move($event, epic.key, item.id)"
            >
              <option
                v-for="option in planning!.workspace.groups"
                :key="option.id"
                :value="option.id"
              >
                {{ option.title }}
              </option>
            </select>
          </div>
        </article>
      </div>
    </section>
    <div v-if="!grouped.length" class="empty-state">
      <WikiIcon name="layers" :size="40" />
      <h2>Здесь пока нет эпиков</h2>
      <p>Измените поиск или перенесите эпики в эту группу.</p>
    </div>
  </template>
</template>
