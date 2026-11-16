<script setup lang="ts">
import { computed, nextTick, ref } from 'vue'
import { planning, developmentPath, taskLabels } from '../lib/planning.ts'
import { releaseRoadmap } from '../lib/release-roadmap.ts'
import WikiIcon from './WikiIcon.vue'

const props = defineProps<{ pilotKeys: readonly string[]; pilotIssue: string }>()
const stages = computed(() =>
  releaseRoadmap(planning.value!.catalog.tasks, props.pilotKeys, props.pilotIssue)
)
const dialog = ref<HTMLDialogElement>()
const selectedId = ref('')
const selected = computed(() =>
  stages.value.flatMap((stage) => stage.cards).find((card) => card.id === selectedId.value)
)
const filter = ref('')
const filteredTasks = computed(() => {
  const query = filter.value.toLocaleLowerCase('ru').trim()
  return (
    selected.value?.tasks
      .filter((task) => `${task.id} ${task.title}`.toLocaleLowerCase('ru').includes(query))
      .sort(
        (left, right) =>
          Number(selected.value!.keys.includes(right.key)) -
          Number(selected.value!.keys.includes(left.key))
      ) ?? []
  )
})
let trigger: HTMLElement | undefined

/** Сохраняет исходную кнопку, чтобы Escape и закрытие возвращали клавиатурный фокус. */
async function openCard(id: string, event: MouseEvent) {
  trigger = event.currentTarget as HTMLElement
  selectedId.value = id
  filter.value = ''
  await nextTick()
  dialog.value?.showModal()
}

function restoreFocus() {
  trigger?.focus({ preventScroll: true })
}
</script>

<template>
  <section class="release-roadmap" aria-labelledby="location-portions">
    <div class="section-heading">
      <div>
        <span class="eyebrow">ОТ ЭТАЛОНА К ВЫПУСКУ</span>
        <h2 id="location-portions">Прогресс по локациям</h2>
      </div>
      <RouterLink class="button" to="/guides/release-roadmap">Решения и границы</RouterLink>
    </div>
    <div class="roadmap-intro planning-panel">
      <strong>Три больших шага до первой демоверсии</strong>
      <p>
        Уютная RPG с живописным миром, отзывчивым управлением и законченным первым приключением.
      </p>
      <div class="roadmap-facts">
        <span>
          <b>10</b>
          карт в демо
        </span>
        <span>
          <b>30</b>
          карт в полной игре
        </span>
        <span>
          <b>0</b>
          недорисованных доступных мест к выпуску
        </span>
      </div>
      <p class="muted">
        Счётчики показывают принятые задачи, а не оставшееся время. Общие зависимости внутри шага
        считаются один раз; между шагами могут повторяться.
      </p>
    </div>
    <section
      v-for="(stage, index) in stages"
      :key="stage.id"
      class="roadmap-stage"
      :aria-labelledby="`roadmap-${stage.id}`"
    >
      <div class="roadmap-stage-heading">
        <span class="location-step">{{ index < 3 ? index + 1 : index === 3 ? '1.0' : '+' }}</span>
        <div>
          <h3 :id="`roadmap-${stage.id}`">{{ stage.title }}</h3>
          <p>{{ stage.outcome }}</p>
        </div>
        <span class="planning-status" :class="stage.accepted ? 'done' : 'backlog'">
          {{ stage.accepted ? 'Принят' : 'Не принят' }}
        </span>
      </div>
      <p v-if="stage.issues.length" class="planning-notice error" role="alert">
        Список неполный: {{ stage.issues.join('; ') }}
      </p>
      <div v-else class="roadmap-stage-progress">
        <progress
          :value="stage.done"
          :max="stage.tasks.length || 1"
          :aria-label="`Принятые задачи: ${stage.title}`"
        />
        <span>{{ stage.done }} / {{ stage.tasks.length }} задач</span>
      </div>
      <details :open="index < 3" class="roadmap-stage-cards">
        <summary>
          Карточки: {{ stage.cards.length }} ·
          {{ index < 3 ? 'состав шага' : 'показать дальнейший план' }}
        </summary>
        <div class="roadmap-grid">
          <button
            v-for="entry in stage.cards"
            :key="entry.id"
            class="planning-panel location-portion roadmap-card"
            type="button"
            aria-haspopup="dialog"
            @click="openCard(entry.id, $event)"
          >
            <span class="location-portion-title">
              <strong>{{ entry.title }}</strong>
              <WikiIcon name="arrow" :size="18" />
            </span>
            <span class="roadmap-card-outcome">{{ entry.outcome }}</span>
            <span v-if="entry.issues.length" class="roadmap-card-count">Список задач неполный</span>
            <span v-else class="roadmap-card-count">
              {{ entry.ownDone }} / {{ entry.ownTotal }} задач карточки
            </span>
            <small v-if="!entry.issues.length" class="muted">
              С общей подготовкой: {{ entry.done }} / {{ entry.tasks.length }} · открыть
            </small>
            <small v-else class="muted">Открыть доступные задачи и причину неполноты</small>
          </button>
        </div>
      </details>
      <div class="roadmap-marker" :class="{ accepted: stage.accepted }">
        <WikiIcon :name="stage.accepted ? 'check' : 'map'" :size="20" />
        <strong>{{ stage.accepted ? stage.marker : `Рубеж: ${stage.marker}` }}</strong>
        <span>
          {{
            stage.accepted
              ? 'Подтверждено карточками приёмки'
              : stage.waitingPrevious
                ? 'Впереди · после предыдущего этапа и собственной приёмки'
                : 'Впереди · после приёмки всех задач этапа'
          }}
        </span>
      </div>
    </section>
    <dialog
      ref="dialog"
      class="location-dialog roadmap-dialog"
      aria-labelledby="roadmap-dialog-title"
      @close="restoreFocus"
      @keydown.esc.stop.prevent="dialog?.close()"
    >
      <header v-if="selected" class="location-dialog-header">
        <div>
          <h2 id="roadmap-dialog-title">{{ selected.title }}</h2>
          <p>
            {{
              selected.issues.length
                ? 'Список неполный'
                : `${selected.done} из ${selected.tasks.length} задач принято`
            }}
          </p>
        </div>
        <form method="dialog"><button class="button" type="submit" autofocus>Закрыть</button></form>
      </header>
      <div v-if="selected" class="roadmap-dialog-body">
        <p>{{ selected.outcome }}</p>
        <p class="muted">
          Задачи из канонических эпиков и все их зависимости. Отметка «Общая зависимость» означает
          подготовку, которая может использоваться несколькими локациями.
        </p>
        <p v-if="selected.issues.length" class="planning-notice error" role="alert">
          {{ selected.issues.join('; ') }}
        </p>
        <label class="roadmap-filter">
          Найти задачу в карточке
          <input v-model="filter" type="search" placeholder="ID или название" />
        </label>
        <p class="muted" role="status">
          Показано {{ filteredTasks.length }} из {{ selected.tasks.length }}
        </p>
        <ol class="location-portion-tasks" aria-label="Задачи дорожной карты">
          <li v-for="task in filteredTasks" :key="task.key">
            <RouterLink :to="developmentPath('tasks', task.key)">
              <span class="planning-code">
                {{ task.id }} ·
                {{
                  planning?.catalog.epics.find((epic) => epic.key === task.epic)?.title ?? task.epic
                }}
              </span>
              <strong>{{ task.title }}</strong>
              <small v-if="!selected.keys.includes(task.key)" class="muted">
                Общая зависимость
              </small>
            </RouterLink>
            <span class="planning-status" :class="task.status">{{ taskLabels[task.status] }}</span>
          </li>
        </ol>
      </div>
    </dialog>
  </section>
</template>
