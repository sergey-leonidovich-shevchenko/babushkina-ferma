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
import { catalog } from '../lib/catalog.ts'
import { queueTasks, queueProgress, queueBlockers, queueIssue } from '../lib/task-queue.ts'

const props = defineProps<{ epicKey?: string }>()
const route = useRoute(),
  router = useRouter()
const limit = ref(50)
const query = computed(() => String(route.query.q ?? ''))
const status = computed(() => String(route.query.status ?? ''))
const plan = computed(() => String(route.query.plan ?? ''))
const queueId = computed(() => String(route.query.queue ?? ''))
const stageId = computed(() => String(route.query.stage ?? ''))
const queues = computed(() => catalog.value?.rolloutQueues ?? [])
const taskIndex = computed(
  () => new Map(planning.value!.catalog.tasks.map((task) => [task.key, task]))
)
const activeQueue = computed(() => queues.value.find((item) => item.id === queueId.value))
const queueError = computed(() => {
  if (stageId.value && !queueId.value) return 'Для этапа сначала выберите очередь.'
  if (!queueId.value || !catalog.value) return ''
  if (!activeQueue.value) return 'Очередь не найдена. Снимите фильтр или пересоберите Wiki.'
  if (stageId.value && !activeQueue.value.stages.some((stage) => stage.id === stageId.value))
    return 'Этап не найден. Снимите фильтр этапа.'
  return queueIssue(activeQueue.value, planning.value!.catalog.tasks)
})
const progress = computed(
  () => activeQueue.value && queueProgress(activeQueue.value, planning.value!.catalog.tasks)
)
const selected = computed(() =>
  props.epicKey
    ? undefined
    : planning.value!.catalog.tasks.find((task) => task.key === route.params.id)
)
const epic = computed(() =>
  planning.value!.catalog.epics.find((item) => item.key === selected.value?.epic)
)
const tasks = computed(() =>
  (queueError.value
    ? []
    : queueId.value
      ? queueTasks(planning.value!.catalog.tasks, activeQueue.value, stageId.value)
      : planning.value!.catalog.tasks
  )
    .filter(
      (task) =>
        (!props.epicKey || task.epic === props.epicKey) &&
        (!status.value || task.status === status.value) &&
        (!plan.value || task.plan === plan.value) &&
        matchesQuery(query.value, task.id, task.title, task.goal)
    )
    .sort((a, b) =>
      activeQueue.value
        ? activeQueue.value.taskKeys.indexOf(a.key) - activeQueue.value.taskKeys.indexOf(b.key)
        : (a.priority || 'P9').localeCompare(b.priority || 'P9') ||
          a.id.localeCompare(b.id, 'ru', { numeric: true })
    )
)
const detailQueue = computed(
  () =>
    activeQueue.value ??
    queues.value.find((item) => item.taskKeys.includes(selected.value?.key ?? ''))
)
const extraDependencies = computed(() =>
  (detailQueue.value?.extraDependencies[selected.value?.key ?? ''] ?? [])
    .map((key) => planning.value!.catalog.tasks.find((task) => task.key === key))
    .filter((task) => !!task)
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
    query: {
      ...route.query,
      ...(key === 'queue' ? { stage: undefined, plan: undefined } : {}),
      [key]: (event.target as HTMLSelectElement).value || undefined,
    },
  })
}
/** Копирует полную карточку вместе с дополнительными условиями пилота, если они существуют. */
function copyCard() {
  if (!selected.value) return
  const extra = extraDependencies.value.length
    ? '\n\nДополнительные условия пилота: ' +
      extraDependencies.value.map((task) => `${task.id} (${taskLabels[task.status]})`).join(', ') +
      '\nОбласть и порядок: Wiki / Руководство / Первый живописный участок.'
    : ''
  copyPlanningText(selected.value.content + extra)
}
</script>

<template>
  <template v-if="!epicKey && route.params.id">
    <RouterLink
      class="planning-back"
      :to="
        queueId
          ? { path: '/development/tasks', query: route.query }
          : epic
            ? developmentPath('epics', epic.key)
            : '/development/tasks'
      "
    >
      <WikiIcon name="back" :size="17" />
      {{ queueId ? 'К очереди пилота' : epic ? epic.title : 'Все задачи' }}
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
      <section v-if="extraDependencies.length">
        <h3>Дополнительные условия пилота</h3>
        <p>
          Полные критерии карточки сохраняются. Эти условия дополняют её место в первой очереди.
        </p>
        <div class="tag-row">
          <RouterLink
            v-for="task in extraDependencies"
            :key="task.key"
            class="planning-dependency"
            :to="{ path: developmentPath('tasks', task.key), query: { queue: detailQueue?.id } }"
          >
            {{ task.id }}
            <span>{{ taskLabels[task.status] }}</span>
          </RouterLink>
        </div>
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
        <button class="button" @click="copyCard">
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
    <section v-if="activeQueue && progress" class="planning-panel rollout-summary">
      <div>
        <span class="eyebrow">ПЕРВАЯ ОЧЕРЕДЬ</span>
        <h2>{{ activeQueue.title }}</h2>
        <p>{{ activeQueue.description }}</p>
      </div>
      <p>
        По текущим карточкам: {{ progress.done }} из {{ progress.total }} завершено · осталось
        {{ progress.total - progress.done }}.
      </p>
      <p v-if="progress.next && !queueError">
        Сейчас можно взять:
        <RouterLink
          :to="{
            path: developmentPath('tasks', progress.next.key),
            query: { queue: queueId, stage: stageId || undefined },
          }"
        >
          {{ progress.next.id }} — {{ progress.next.title }}
        </RouterLink>
      </p>
      <p v-else-if="progress.preparable && !queueError">
        Можно подготовить к работе: {{ progress.preparable.id }}. Исходный статус «В плане»
        сохранён.
      </p>
      <RouterLink :to="`/guides/${activeQueue.guide}`">
        Область, критерии и следующие этапы
      </RouterLink>
    </section>
    <p v-if="queueError" class="planning-notice error" role="alert">{{ queueError }}</p>
    <div class="planning-toolbar">
      <label v-if="!epicKey" class="planning-select">
        Очередь
        <select :value="queueId" @change="filter('queue', $event)">
          <option value="">Все задачи</option>
          <option v-for="item in queues" :key="item.id" :value="item.id">{{ item.title }}</option>
        </select>
      </label>
      <label v-if="activeQueue" class="planning-select">
        Этап
        <select :value="stageId" @change="filter('stage', $event)">
          <option value="">Все этапы</option>
          <option v-for="stage in activeQueue.stages" :key="stage.id" :value="stage.id">
            {{ stage.title }}
          </option>
        </select>
      </label>
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
        :to="{
          path: developmentPath('tasks', task.key),
          query: { queue: queueId || undefined, stage: stageId || undefined },
        }"
        class="planning-task-row"
      >
        <span class="planning-code">{{ task.id }}</span>
        <span class="planning-task-title">
          {{ task.title }}
          <small>{{ planning!.catalog.epics.find((item) => item.key === task.epic)?.title }}</small>
          <small v-if="activeQueue && queueBlockers(task, activeQueue, taskIndex).length">
            Открытых условий: {{ queueBlockers(task, activeQueue, taskIndex).length }}
          </small>
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
