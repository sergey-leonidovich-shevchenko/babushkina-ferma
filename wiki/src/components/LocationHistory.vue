<script setup lang="ts">
import { nextTick, ref } from 'vue'
import { assetUrl } from '../lib/catalog.ts'
import type { PlanTask, TaskComparison } from '../lib/planning.ts'
import { developmentPath } from '../lib/planning.ts'

defineProps<{ tasks: (PlanTask & { context: string })[] }>()

const captureLabels = { before: 'До', after: 'После' }
const captureDialog = ref<HTMLDialogElement>()
const selectedCapture = ref<{ src: string; title: string }>()
let captureTrigger: HTMLElement | undefined

async function openCapture(
  comparison: TaskComparison,
  side: keyof typeof captureLabels,
  event: MouseEvent
) {
  captureTrigger = event.currentTarget as HTMLElement
  selectedCapture.value = {
    src: assetUrl(comparison[side]),
    title: `${captureLabels[side]} · ${comparison.label}`,
  }
  await nextTick()
  captureDialog.value?.showModal()
}

function closeCapture() {
  selectedCapture.value = undefined
  captureTrigger?.focus({ preventScroll: true })
}
</script>

<template>
  <section class="planning-panel location-history" aria-labelledby="location-history-title">
    <h2 id="location-history-title">История выполненного</h2>
    <p class="muted">
      Завершённые задачи маршрута и его технического обслуживания · {{ tasks.length }}. Новые даты
      сверху; без подтверждённой даты — в конце. Это история работы, а не процент приёмки всей
      карты.
    </p>
    <ol v-if="tasks.length" class="location-history-list" aria-label="Завершённые задачи">
      <li v-for="task in tasks" :key="task.key" :data-task-key="task.key">
        <div class="location-history-date">
          <time v-if="task.completion?.date" :datetime="task.completion.date">
            {{ task.completion.date.split('-').reverse().join('.') }}
          </time>
          <span v-else>Дата не указана</span>
          <small v-if="task.completion?.date">{{ task.completion.basis }}</small>
        </div>
        <div class="location-history-entry">
          <RouterLink :to="developmentPath('tasks', task.key)">
            <span class="planning-code">{{ task.id }}</span>
            <strong>{{ task.title }}</strong>
          </RouterLink>
          <p class="muted">{{ task.context }}</p>
          <details v-if="task.completion?.evidence.length">
            <summary>Материалы и подтверждения · {{ task.completion.evidence.length }}</summary>
            <ul>
              <li v-for="proof in task.completion.evidence" :key="proof.url">
                <a :href="proof.url">{{ proof.label }}</a>
              </li>
            </ul>
          </details>
          <details v-if="task.completion?.comparison" class="location-comparison">
            <summary>До и после</summary>
            <p>{{ task.completion.comparison.label }}</p>
            <div class="location-comparison-grid">
              <button
                v-for="(label, side) in captureLabels"
                :key="side"
                class="location-thumbnail"
                type="button"
                aria-haspopup="dialog"
                :aria-label="`Открыть снимок «${label}»`"
                @click="openCapture(task.completion.comparison, side, $event)"
              >
                <img
                  :src="assetUrl(task.completion.comparison[side])"
                  :width="task.completion.comparison.width"
                  :height="task.completion.comparison.height"
                  alt=""
                  loading="lazy"
                />
                <span>{{ label }}</span>
              </button>
            </div>
          </details>
        </div>
      </li>
    </ol>
    <p v-else class="muted">В маршруте и его техническом обслуживании ещё нет завершённых задач.</p>
    <dialog
      ref="captureDialog"
      class="location-dialog location-image-dialog"
      aria-labelledby="location-image-title"
      @close="closeCapture"
      @keydown.esc.stop.prevent="captureDialog?.close()"
    >
      <template v-if="selectedCapture">
        <header class="location-dialog-header">
          <h2 id="location-image-title">{{ selectedCapture.title }}</h2>
          <form method="dialog">
            <button class="button" type="submit" autofocus>Закрыть</button>
          </form>
        </header>
        <img :src="selectedCapture.src" :alt="selectedCapture.title" />
      </template>
    </dialog>
  </section>
</template>
