<script setup lang="ts">
import { computed, nextTick, ref } from 'vue'
import { catalog } from '../lib/catalog.ts'
import { planning, developmentPath, taskLabels } from '../lib/planning.ts'
import { firstLocationOverview, locationPortions } from '../lib/first-location.ts'
import { queueProgress, queueIssue } from '../lib/task-queue.ts'
import WikiIcon from './WikiIcon.vue'
import LocationHistory from './LocationHistory.vue'

const overview = computed(() => firstLocationOverview(planning.value!.catalog))
const pilot = computed(() =>
  catalog.value?.rolloutQueues?.find((queue) => queue.id === 'village-pilot')
)
const pilotError = computed(() =>
  pilot.value
    ? queueIssue(pilot.value, planning.value!.catalog.tasks)
    : 'Очередь пилота недоступна. Пересоберите Wiki.'
)
const portions = computed(() =>
  locationPortions(planning.value!.catalog.tasks, pilotError.value ? [] : pilot.value?.taskKeys)
)
const portionsDialog = ref<HTMLDialogElement>()
const selectedId = ref('')
const selectedPortion = computed(() =>
  portions.value.find((portion) => portion.id === selectedId.value)
)
let portionTrigger: HTMLElement | undefined

async function openPortion(id: string, event: MouseEvent) {
  portionTrigger = event.currentTarget as HTMLElement
  selectedId.value = id
  await nextTick()
  portionsDialog.value?.showModal()
}

function closePortion() {
  portionTrigger?.focus({ preventScroll: true })
}

const progress = computed(() =>
  pilot.value && !pilotError.value
    ? queueProgress(pilot.value, planning.value!.catalog.tasks)
    : undefined
)
</script>

<template>
  <div class="first-location-board">
    <section class="planning-panel location-summary" aria-label="Текущая цель">
      <div>
        <span class="eyebrow">ЦЕЛЬ · ВСЯ OVERWORLD</span>
        <h2>{{ overview.accepted ? 'Первая локация принята' : 'До приёмки VMAP-003' }}</h2>
        <p>
          Набережная, двор, огород, площадь, загоны, фасады, оба моста и края карты — в мягком
          живописном стиле A.
        </p>
      </div>
      <div class="location-links">
        <RouterLink class="button" to="/guides/visual-pilot">
          <WikiIcon name="map" :size="18" />
          Эталоны и порядок работы
        </RouterLink>
        <RouterLink class="button" to="/development/tasks?queue=village-pilot">
          Задачи пилота
          <WikiIcon name="arrow" :size="16" />
        </RouterLink>
      </div>
      <p class="muted">
        Статусы обновляются каждые 30 секунд и по кнопке «Обновить». Состав всей карты уточняет
        VMAP-001; готовность подтверждает VMAP-003.
      </p>
    </section>

    <section aria-labelledby="location-portions">
      <div class="section-heading"><h2 id="location-portions">Прогресс по локациям</h2></div>
      <div class="location-portion-grid">
        <button
          v-for="(portion, index) in portions"
          :key="portion.id"
          class="planning-panel location-portion"
          type="button"
          aria-haspopup="dialog"
          @click="openPortion(portion.id, $event)"
        >
          <span class="location-portion-title">
            <strong>{{ portion.title }}</strong>
            <WikiIcon name="arrow" :size="20" />
          </span>
          <span>{{ portion.done }} из {{ portion.tasks.length }} задач завершено</span>
          <progress :value="portion.done" :max="portion.tasks.length || 1" aria-hidden="true" />
          <small v-if="index" class="muted">План после первой локации</small>
          <small v-else class="muted">Объём уточнит VMAP-001</small>
        </button>
      </div>
      <p v-if="pilotError" class="planning-notice error" role="alert">{{ pilotError }}</p>
      <dialog
        ref="portionsDialog"
        class="location-dialog location-tasks-dialog"
        aria-labelledby="location-portion-dialog-title"
        @close="closePortion"
        @keydown.esc.stop.prevent="portionsDialog?.close()"
      >
        <header v-if="selectedPortion" class="location-dialog-header">
          <div>
            <h2 id="location-portion-dialog-title">{{ selectedPortion.title }}</h2>
            <p class="muted">
              {{ selectedPortion.done }} из {{ selectedPortion.tasks.length }} задач завершено
            </p>
          </div>
          <form method="dialog">
            <button class="button" type="submit" autofocus>Закрыть</button>
          </form>
        </header>
        <p v-if="selectedPortion?.missing.length" class="planning-notice error" role="alert">
          Недоступные карточки: {{ selectedPortion.missing.join(', ') }}. Обновите данные.
        </p>
        <ol v-if="selectedPortion" class="location-portion-tasks" aria-label="Задачи локации">
          <li v-for="task in selectedPortion.tasks" :key="task.key">
            <RouterLink :to="developmentPath('tasks', task.key)">
              <span class="planning-code">{{ task.id }}</span>
              <strong>{{ task.title }}</strong>
            </RouterLink>
            <span class="planning-status" :class="task.status">{{ taskLabels[task.status] }}</span>
          </li>
        </ol>
      </dialog>
    </section>

    <section class="planning-panel location-current" aria-labelledby="location-current-title">
      <h2 id="location-current-title">Сейчас в работе</h2>
      <div v-if="overview.active.length" class="location-active">
        <RouterLink
          v-for="task in overview.active"
          :key="task.key"
          :to="developmentPath('tasks', task.key)"
        >
          <span class="planning-code">{{ task.id }}</span>
          <strong>{{ task.title }}</strong>
          <span class="muted">{{ task.context }}</span>
        </RouterLink>
      </div>
      <p v-else class="muted">В общем каталоге сейчас нет задач со статусом «В работе».</p>
      <template v-if="progress?.next">
        <p class="muted">
          {{
            overview.active.length
              ? 'Следующая готовая карточка пилота'
              : 'Готова к работе в пилоте'
          }}
        </p>
        <RouterLink :to="developmentPath('tasks', progress.next.key)">
          {{ progress.next.id }} · {{ progress.next.title }}
        </RouterLink>
      </template>
    </section>

    <section aria-labelledby="location-gates">
      <div class="section-heading"><h2 id="location-gates">Этапы приёмки</h2></div>
      <ol class="location-milestones">
        <li v-for="(gate, index) in overview.milestones" :key="gate.id" class="planning-panel">
          <span class="location-step">{{ index + 1 }}</span>
          <div>
            <RouterLink v-if="gate.task" :to="developmentPath('tasks', gate.task.key)">
              <strong>{{ gate.title }}</strong>
              <span class="planning-code">{{ gate.id }}</span>
            </RouterLink>
            <strong v-else>{{ gate.title }} · {{ gate.id }}</strong>
          </div>
          <span class="planning-status" :class="gate.task?.status">
            {{ gate.task ? taskLabels[gate.task.status] : 'Нет данных' }}
          </span>
        </li>
      </ol>
    </section>

    <LocationHistory :tasks="overview.history" />

    <p class="planning-notice">
      Ниже — те же эпики из общего каталога. Их счётчики читают исходные карточки. Для VBUILD,
      VACTOR и VPLANT состав первой карты определит VMAP-001; остальные карты и новые механики ждут
      её приёмки.
    </p>
    <section v-for="group in overview.groups" :key="group.title" class="epic-group">
      <div class="section-heading">
        <h2>{{ group.title }}</h2>
      </div>
      <p class="muted">{{ group.goal }}</p>
      <div class="epic-grid">
        <article v-for="row in group.epics" :key="row.key" class="epic-card">
          <template v-if="row.epic">
            <div class="epic-card-top">
              <span class="planning-code">{{ row.epic.id }}</span>
              <span v-if="row.counts.in_progress" class="planning-status in_progress">
                В работе
              </span>
            </div>
            <RouterLink :to="developmentPath('epics', row.key)">
              <h3>{{ row.epic.title }}</h3>
            </RouterLink>
            <p class="location-scope">{{ row.scope }}</p>
            <div class="epic-progress">
              <span>{{ row.counts.done }} из {{ row.total }} завершено</span>
              <span>{{ row.total ? Math.round((row.counts.done! / row.total) * 100) : 0 }}%</span>
            </div>
            <progress
              :value="row.counts.done ?? 0"
              :max="row.total || 1"
              :aria-label="`Выполнение ${row.epic.id}`"
            />
            <div class="location-counts">
              <span>В работе: {{ row.counts.in_progress }}</span>
              <span>Готовы: {{ row.counts.ready }}</span>
              <span>Заблокированы: {{ row.counts.blocked }}</span>
            </div>
            <div class="epic-card-foot">
              <RouterLink :to="developmentPath('epics', row.key)">
                Открыть эпик
                <WikiIcon name="arrow" :size="15" />
              </RouterLink>
            </div>
          </template>
          <p v-else class="planning-notice error" role="alert">
            Эпик {{ row.key }} недоступен. Обновите данные.
          </p>
        </article>
      </div>
    </section>
  </div>
</template>
