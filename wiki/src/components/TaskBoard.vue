<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import {
  planning,
  developmentPath,
  matchesQuery,
  taskLabels,
  findTask,
  copyPlanningText,
} from '../lib/planning.ts'
import WikiIcon from './WikiIcon.vue'

const props = defineProps<{ epicKey?: string }>()
const route = useRoute(),
  router = useRouter()
const limit = ref(50)
const query = computed(() => String(route.query.q ?? ''))
const status = computed(() => String(route.query.status ?? ''))
const plan = computed(() => String(route.query.plan ?? ''))
const selected = computed(() =>
  props.epicKey
    ? undefined
    : planning.value!.catalog.tasks.find((task) => task.key === route.params.id)
)
const epic = computed(() =>
  planning.value!.catalog.epics.find((item) => item.key === selected.value?.epic)
)
const tasks = computed(() =>
  planning
    .value!.catalog.tasks.filter(
      (task) =>
        (!props.epicKey || task.epic === props.epicKey) &&
        (!status.value || task.status === status.value) &&
        (!plan.value || task.plan === plan.value) &&
        matchesQuery(query.value, task.id, task.title, task.goal)
    )
    .sort(
      (a, b) =>
        (a.priority || 'P9').localeCompare(b.priority || 'P9') ||
        a.id.localeCompare(b.id, 'ru', { numeric: true })
    )
)
watch(
  () => route.fullPath,
  () => {
    limit.value = 50
  }
)
/** Сохраняет фильтры вместе с текущим разделом и поиском. */
function filter(key: string, event: Event) {
  router.replace({
    query: { ...route.query, [key]: (event.target as HTMLSelectElement).value || undefined },
  })
}
</script>

<template>
  <template v-if="!epicKey && route.params.id">
    <RouterLink
      class="planning-back"
      :to="epic ? developmentPath('epics', epic.key) : '/development/tasks'"
    >
      <WikiIcon name="back" :size="17" />
      {{ epic ? epic.title : 'Все задачи' }}
    </RouterLink>
    <article v-if="selected" class="planning-panel task-detail">
      <div class="planning-detail-meta">
        <span class="planning-code">{{ selected.id }}</span>
        <span class="planning-status" :class="selected.status">
          {{ taskLabels[selected.status] }}
        </span>
        <span v-if="selected.priority">{{ selected.priority }}</span>
        <span v-if="selected.size">Объём {{ selected.size }}</span>
      </div>
      <h2>{{ selected.title }}</h2>
      <p class="planning-prose">{{ selected.goal }}</p>
      <section v-if="selected.dependencies.length">
        <h3>Зависимости</h3>
        <div class="tag-row">
          <template v-for="id in selected.dependencies" :key="id">
            <RouterLink
              v-if="findTask(id, selected.plan)"
              class="planning-dependency"
              :to="developmentPath('tasks', findTask(id, selected.plan)!.key)"
            >
              {{ id }}
              <span>{{ taskLabels[findTask(id, selected.plan)!.status] }}</span>
            </RouterLink>
            <span v-else class="tag">{{ id }}</span>
          </template>
        </div>
      </section>
      <section v-if="selected.acceptance.length">
        <h3>Критерии приёмки</h3>
        <ul class="planning-criteria">
          <li v-for="(criterion, index) in selected.acceptance" :key="index">{{ criterion }}</li>
        </ul>
      </section>
      <section v-for="(item, index) in selected.sections" :key="index">
        <h3>{{ item.title }}</h3>
        <p class="planning-prose">{{ item.text }}</p>
      </section>
      <section>
        <h3>Подтверждения и результат</h3>
        <p class="planning-prose">
          {{
            selected.result ||
            'Подтверждения ещё не записаны. Карточка не означает готовую игровую механику.'
          }}
        </p>
      </section>
      <div class="planning-detail-actions">
        <button class="button" @click="copyPlanningText(selected.content)">
          <WikiIcon name="copy" :size="17" />
          Скопировать карточку агенту
        </button>
        <span class="muted">
          {{ planning!.catalog.plans.find((item) => item.id === selected?.plan)?.title }}
        </span>
      </div>
    </article>
    <div v-else class="empty-state">
      <h2>Задача не найдена</h2>
      <p>Обновите список или вернитесь ко всем задачам.</p>
    </div>
  </template>
  <template v-else>
    <div class="planning-toolbar">
      <label class="planning-search">
        <WikiIcon name="search" :size="18" />
        <input
          :value="query"
          placeholder="Название, ID или результат задачи"
          aria-label="Поиск задач"
          @input="filter('q', $event)"
        />
      </label>
      <label class="planning-select">
        Статус
        <select :value="status" @change="filter('status', $event)">
          <option value="">Все статусы</option>
          <option v-for="(label, id) in taskLabels" :key="id" :value="id">{{ label }}</option>
        </select>
      </label>
      <label v-if="!epicKey" class="planning-select">
        План
        <select :value="plan" @change="filter('plan', $event)">
          <option value="">Все планы</option>
          <option v-for="item in planning!.catalog.plans" :key="item.id" :value="item.id">
            {{ item.title }}
          </option>
        </select>
      </label>
    </div>
    <p class="muted planning-results-count">
      Найдено {{ tasks.length }} · показано {{ Math.min(limit, tasks.length) }}
    </p>
    <div v-if="tasks.length" class="planning-task-list">
      <RouterLink
        v-for="task in tasks.slice(0, limit)"
        :key="task.key"
        :to="developmentPath('tasks', task.key)"
        class="planning-task-row"
      >
        <span class="planning-code">{{ task.id }}</span>
        <span class="planning-task-title">
          {{ task.title }}
          <small>{{ planning!.catalog.epics.find((item) => item.key === task.epic)?.title }}</small>
        </span>
        <span class="planning-status" :class="task.status">{{ taskLabels[task.status] }}</span>
        <span class="planning-priority">{{ task.priority }}</span>
        <WikiIcon name="chevron" :size="17" />
      </RouterLink>
    </div>
    <button v-if="tasks.length > limit" class="button planning-more" @click="limit += 50">
      Показать ещё {{ Math.min(50, tasks.length - limit) }}
    </button>
    <div v-if="!tasks.length" class="empty-state">
      <WikiIcon name="checklist" :size="40" />
      <h2>Задач не найдено</h2>
      <p>Попробуйте другой запрос или снимите фильтры.</p>
    </div>
  </template>
</template>
